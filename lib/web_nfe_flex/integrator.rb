require 'ostruct'
require 'yaml'
require 'erb'

module NFe
  module Integration
    module WebNfeFlex

      def self.config
        c = OpenStruct.new(YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), 'app_config.yml'))).result))
        e = c.send(RAILS_ENV)
        c.common ||= {}
        c.common.update(e) unless e.nil?
        OpenStruct.new(c.common)
      end

      def self.find_nota_fiscal(nf_id)
        if nf = WebNfeFlexModels::NotaFiscal.find_by_id(nf_id.to_i)
          nf.values
        end
      end

      def self.after_xml_construction(nf_xml)
        num_nf = nf_xml.numero.to_i
        if nf_xml.numero_fatura.blank? && nf_xml.duplicatas.size > 0
          nf_xml.numero_fatura = nf_xml.numero.to_s
        end

        nf_xml.duplicatas.each_with_index do |dup, i|
          dup.numero = "%d-%s" % [num_nf, (65 + i).chr] if dup.numero.blank? || dup.numero == '0'
        end
      end

      def self.notify_progress(source_obj)
      end

      def self.notify_completion(nf_id, source_obj)
        nf = WebNfeFlexModels::NotaFiscal.find_by_id(nf_id.to_i)

        if ConsultaNotaFiscal === source_obj
          source_obj = source_obj.nota_fiscal
        end

        if nf
          autorizada = source_obj.codigo_status_efetivo == '100'
          denegada = source_obj.codigo_status_efetivo.to_i >= 300 && source_obj.codigo_status_efetivo.to_i < 400

          if autorizada || denegada
            status = autorizada ? 'autorizada' : 'denegada'

            nf.update_attributes!(
                'numero' => source_obj.numero.to_i,
                'serie' => source_obj.serie.to_s,
                'numero_fatura' => source_obj.request_xml.document.numero_fatura.to_s,
                'chave_nfe' => source_obj.chave.to_s,
                'status' => status,
                'status_sefaz' => source_obj.codigo_status_efetivo,
                'mensagem_sefaz' => source_obj.mensagem_status_efetiva.to_s)

            nf.duplicatas.each_with_index do |dup, i|
              if dup.numero.blank?
                dup.update_attributes!('numero' => source_obj.request_xml.document.duplicatas[i].numero)
              end
            end

          elsif source_obj.codigo_status_efetivo == '135'
            nf.update_attributes!(
                'status' => 'cancelada',
                'status_sefaz' => source_obj.codigo_status_efetivo,
                'mensagem_sefaz' => source_obj.mensagem_status_efetiva.to_s)

          else
            operacao = source_obj.respond_to?(:nota_fiscal) ? 'cancelamento' : 'autorizacao'
            nf.update_attributes!(
                'status' => "erro_#{operacao}",
                'status_sefaz' => source_obj.codigo_status_efetivo,
                'mensagem_sefaz' => source_obj.mensagem_status_efetiva.to_s)
          end

          c = config
          path = "#{c.web_nfe_flex_address}/notas_fiscais/#{nf_id.to_i}/push"
          url = URI.parse(path)
          http = Net::HTTP::new(url.host, url.port)
          if url.scheme == 'https'
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
          http.start do |x|
            x.get(url.path)
          end
        end
      end

      def self.notify_completion_cce(nf_id, source_obj)
        n_seq = source_obj.request_xml.document.numero_sequencial_evento
        # busca cce do flex
        cce = WebNfeFlexModels::CartaCorrecao.find_by_nota_fiscal_id_and_versao(nf_id, n_seq)
        return unless cce
        autorizada = source_obj.codigo_status == '135' || source_obj.codigo_status == '136'
        # atualiza
        cce.update_attributes!(
          :status => autorizada ? "autorizada" : "erro",
          :status_sefaz => source_obj.codigo_status.to_s,
          :mensagem_sefaz => source_obj.mensagem_status.to_s
        )
        # invalida cces anteriores da mesma nota
        if autorizada
          WebNfeFlexModels::CartaCorrecao.update_all({:status => "substituida"}, [ "nota_fiscal_id = ?  and status = ? and id <> ?",
                                   nf_id, "autorizada", cce.id])
        end
        c = config
        path = "#{c.web_nfe_flex_address}/notas_fiscais/#{nf_id.to_i}/cartas_correcao/#{n_seq}/push"
        url = URI.parse(path)
        http = Net::HTTP::new(url.host, url.port)
        if url.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        http.start do |x|
          x.get(url.path)
        end
      end

      def self.find_nota_fiscal_servico(cidade, nf_id)
        nf_id = nf_id.gsub("nfse:", "").to_i
        if cidade == 'curitiba'
          klass = WebNfeFlexModels::NotaFiscalServico
        elsif cidade = 'sao_paulo'
          klass = WebNfeFlexModels::NotaFiscalSaoPaulo
        end
        if nf = klass.find_by_id(nf_id.to_i)
          nf.values
        end
      end

      def self.notify_completion_nfse(nf_id, source_obj)
        nf_id = nf_id.gsub("nfse:", "").to_i
        # busca nfse
        nfse = WebNfeFlexModels::NotaFiscalServico.find_by_id(nf_id)
        return unless nfse
        # verifica resposta
        response = source_obj.lote_rps.response_xml.document
        rps = source_obj.lote_rps.rps.first
        if response.sucesso == "false"
          # adiciona mensagens de erro
          msgs = []
          response.alertas.each do |alerta|
            msgs << alerta.codigo + ' - '+alerta.mensagem
          end
          response.erros.each do |erro|
            msgs << erro.codigo + ' - '+erro.mensagem
          end
          nfse.status = 'erro_autorizacao'
          nfse.mensagem_prefeitura = msgs.join("\n")
          nfse.status_prefeitura = source_obj.lote_rps.situacao
        else
          # atualiza infos da nfse (status, url, valor iss)
          nfse.status = 'autorizada'
          nfse.status_prefeitura = source_obj.lote_rps.situacao
          # mesmo autorizada pode haver alertas
          msgs = []
          response.alertas.each do |alerta|
            msgs << alerta.codigo + ' - '+alerta.mensagem
          end
          nfse.mensagem_prefeitura = msgs.join("\n")
          nfse.numero = rps.numero
          nfse.numero_rps = rps.numero_rps
          nfse.serie_rps = rps.serie_rps
          # url
          nfse.url = rps.uri
          # codigo verificacao
          nfse.codigo_verificacao = rps.codigo_verificacao
        end
        nfse.save
        # avisa juggernaut
        c = config
        path = "#{c.web_nfe_flex_address}/notas_fiscais_servico/#{nf_id.to_i}/push"
        url = URI.parse(path)
        http = Net::HTTP::new(url.host, url.port)
        if url.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        http.start do |x|
          x.get(url.path)
        end
      end
    end
  end
end
