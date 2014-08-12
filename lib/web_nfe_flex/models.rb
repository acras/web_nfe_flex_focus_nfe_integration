module WebNfeFlexModels

  class WebNfeFlexModel < ActiveRecord::Base
    db_config = File.open(File.dirname(__FILE__) + '/database.yml') { |x| YAML.load(x) }
    establish_connection(db_config[ENV['RAILS_ENV'] || 'development'])

    def self.codigos_uf_ibge
      { 'AC' => '12', 'AL' => '27', 'AP' => '16',
        'AM' => '13', 'BA' => '29', 'CE' => '23',
        'DF' => '53', 'ES' => '32', 'GO' => '52',
        'MA' => '21', 'MT' => '51', 'MS' => '50',
        'MG' => '31', 'PA' => '15', 'PB' => '25',
        'PR' => '41', 'PE' => '26', 'PI' => '22',
        'RJ' => '33', 'RN' => '24', 'RS' => '43',
        'RO' => '11', 'RR' => '14', 'SC' => '42',
        'SP' => '35', 'SE' => '28', 'TO' => '17' }
      end
  end

  class Municipio < WebNfeFlexModel
    set_table_name 'municipios'
  end

  class Pais < WebNfeFlexModel
    set_table_name 'paises'
  end

  class Cfop < WebNfeFlexModel
    set_table_name 'cfops'
  end

  class Emitente < WebNfeFlexModel
    set_table_name 'emitentes'

    belongs_to  :configuracao,
                :class_name => 'WebNfeFlexModels::Configuracao',
                :foreign_key => 'configuracao_id'
  end

  class CapituloNcm < WebNfeFlexModel
    set_table_name 'capitulos_ncm'
  end

  class Configuracao < WebNfeFlexModel
    set_table_name 'configuracoes'

    belongs_to  :capitulo_ncm,
                :class_name => 'WebNfeFlexModels::CapituloNcm',
                :foreign_key => 'capitulo_ncm_id'
  end
  
  class Domain < WebNfeFlexModel
    set_table_name 'domains'
    
    belongs_to :configuracao,
               :class_name => 'WebNfeFlexModels::Configuracao'
  end

  class NotaFiscal < WebNfeFlexModel
    set_table_name 'notas_fiscais'

    has_many  :itens,
              :class_name => 'WebNfeFlexModels::Item',
              :foreign_key => 'nota_fiscal_id',
              :order => 'numero asc'
    has_many  :duplicatas,
              :class_name => 'WebNfeFlexModels::Duplicata',
              :foreign_key => 'nota_fiscal_id',
              :order => 'data_vencimento asc'
    has_many  :volumes,
              :class_name => 'WebNfeFlexModels::Volume',
              :foreign_key => 'nota_fiscal_id'
    has_many  :referenciadas,
              :class_name => 'WebNfeFlexModels::Referenciada',
              :foreign_key => 'nota_fiscal_id'

    belongs_to  :person,
                :class_name => 'WebNfeFlexModels::Person',
                :foreign_key => 'person_id'
    belongs_to  :emitente,
                :class_name => 'WebNfeFlexModels::Emitente',
                :foreign_key => 'emitente_id'
    belongs_to  :transporter,
                :class_name => 'WebNfeFlexModels::Transporter',
                :foreign_key => 'transporter_id'
    belongs_to  :municipio_entrega,
                :class_name => 'WebNfeFlexModels::Municipio',
                :foreign_key => 'municipio_entrega_id'
    belongs_to  :municipio_retirada,
                :class_name => 'WebNfeFlexModels::Municipio',
                :foreign_key => 'municipio_retirada_id'
    belongs_to  :transporte_icms_cfop,
                :class_name => 'WebNfeFlexModels::Cfop',
                :foreign_key => 'transporte_icms_cfop_id'
    belongs_to  :transporte_icms_municipio,
                :class_name => 'WebNfeFlexModels::Municipio',
                :foreign_key => 'transporte_icms_municipio_id'
    belongs_to  :domain,
                :class_name => 'WebNfeFlexModels::Domain'

    def values
      result = attributes.clone
      result.symbolize_keys!

      result.update(self.person.values) if self.person
      result.update(self.transporter.values) if self.transporter

      if self.emitente
        result[:cnpj_emitente] = self.emitente.cnpj
        result[:uf_emitente] = self.emitente.uf
        result[:regime_tributario_emitente] = self.emitente.regime_tributario
      end

      if !self.municipio_entrega_id.blank?
        result[:codigo_municipio_entrega] = self.municipio_entrega.codigo_municipio
        result[:municipio_entrega] = self.municipio_entrega.nome_municipio
        result[:uf_entrega] = self.municipio_entrega.sigla_uf
      end

      if !self.municipio_retirada_id.blank?
        result[:codigo_municipio_retirada] = self.municipio_retirada.codigo_municipio
        result[:municipio_retirada] = self.municipio_retirada.nome_municipio
        result[:uf_retirada] = self.municipio_retirada.sigla_uf
      end

      if self.transporte_icms_cfop
        result[:transporte_icms_cfop] = self.transporte_icms_cfop.codigo
      end

      if self.transporte_icms_municipio
        result[:transporte_icms_codigo_municipio] = self.transporte_icms_municipio.codigo_municipio
      end

      result[:items] = self.itens.collect { |x| x.values }
      result[:duplicatas] = self.duplicatas.collect { |x| x.values }
      result[:volumes] = self.volumes.collect { |x| x.values }
      result[:notas_referenciadas] = self.referenciadas.collect { |x| x.values }

      [:id, :created_at, :updated_at, :destinatario_id, :emitente_id, :status_sefaz,
          :mensagem_sefaz, :chave_nfe, :revenda, :ultima_etapa, :impostos_calculados,
          :justificativa_cancelamento, :domain_id, :transportador_id, :status, :tipo_venda,
          :valor_total_bruto, :municipio_entrega_id, :municipio_retirada_id, :veiculo_tipo,
          :devolucao_consignacao, :transporte_icms_municipio_id,
          :transporte_icms_cfop_id, :modelo_nota_fiscal_id].each { |x| result.delete(x) }

      result
    end
  end

  class CartaCorrecao < WebNfeFlexModel
    set_table_name 'cartas_correcao'
    belongs_to :nota_fiscal
  end

  class Person < WebNfeFlexModel
    set_table_name 'people'

    has_many :contact_infos,
      :order => 'created_at ASC',
      :class_name => 'WebNfeFlexModels::ContactInfo',
      :foreign_key => 'person_id'
    has_one :default_address,
      :class_name => "WebNfeFlexModels::Address",
      :conditions => {:address_type => 'default'},
      :foreign_key => 'person_id'
    has_one :billing_address,
      :class_name => "WebNfeFlexModels::Address",
      :conditions => {:address_type => 'billing'},
      :foreign_key => 'person_id'

    def self.inheritance_column
      nil
    end

    def values
      result = {}
      [:cpf, :inscricao_suframa, :regime_simples_nacional, :inscricao_municipal].each {|x| result[x] = send(x) }

      if !self.nfe_address.municipio_id.blank?
        result[:codigo_municipio] = self.nfe_address.municipio.codigo_municipio
        result[:municipio] = self.nfe_address.municipio.nome_municipio
        result[:uf] = self.nfe_address.municipio.sigla_uf
      end
      [:logradouro, :bairro, :numero, :complemento, :cep].each { |x| result[x] = nfe_address.send(x) }
      if !self.nfe_address.pais_id.blank?
        result[:codigo_pais] = self.nfe_address.pais.codigo
        result[:pais] = self.nfe_address.pais.nome
      end
      result[:telefone] = self.phone unless self.phone.blank?
      result[:email] = self.email unless self.email.blank?
      if legal_type == 'LEGAL'
        result[:nome] = self.razao_social
      else
        result[:nome] = self.name
      end

      # verifica se usa cnpj_emissao
      if !cnpj_emissao.blank?
        result[:cnpj] = cnpj_emissao
        result[:inscricao_estadual] = (self.isento_inscricao_estadual_emissao ? 'ISENTO' : self.inscricao_estadual_emissao)
      else
        result[:cnpj] = cnpj
        result[:inscricao_estadual] = (self.isento_inscricao_estadual ? 'ISENTO' : self.inscricao_estadual)
      end

      result_temp = result
      result = {}
      result_temp.each do |attribute, value|
        result[(attribute.to_s + '_destinatario').to_sym] = value
      end

      result
    end

    def nfe_address
      if billing_address && billing_address.nfe_enabled?
        billing_address
      else
        default_address
      end
    end

    def first_contact_value_by_type(type)
      contact_infos.to_ary.find {|o| o.contact_type == type}.try(:value)
    end

    def phone
      first_contact_value_by_type('phone')
    end

    def email
      first_contact_value_by_type('email')
    end

  end

  class Address < WebNfeFlexModel
    set_table_name 'addresses'
    belongs_to :municipio,
      :class_name => "WebNfeFlexModels::Municipio",
      :foreign_key => 'municipio_id'
    belongs_to :pais,
      :class_name => "WebNfeFlexModels::Pais",
      :foreign_key => 'pais_id'

    def nfe_enabled?
      !bairro.blank? && !numero.blank? && !municipio_id.blank? && !pais_id.blank? && !logradouro.blank? && !cep.blank?
    end

  end

  class ContactInfo < WebNfeFlexModel
    set_table_name 'contact_infos'
  end

  class Transporter < WebNfeFlexModel
    set_table_name 'people'

    def self.inheritance_column
      nil
    end

    has_one :default_address,
      :class_name => "WebNfeFlexModels::Address",
      :conditions => {:address_type => 'default'},
      :foreign_key => 'person_id'


    def values
      result = {}
      [:endereco_completo, :cnpj, :cpf, :inscricao_estadual].each {|x| result[x] = send(x) }

      result[:endereco] = result.delete(:endereco_completo)
      if !self.default_address.municipio_id.blank?
        result[:municipio] = self.default_address.municipio.nome_municipio
        result[:uf] = self.default_address.municipio.sigla_uf
      end

      result[:nome] = self.name

      result_temp = result
      result = {}
      result_temp.each do |attribute, value|
        result[(attribute.to_s + '_transportador').to_sym] = value
      end

      result
    end
  end

  class Item < WebNfeFlexModel
    set_table_name 'itens'

    has_many  :documentos_importacao,
              :class_name => 'WebNfeFlexModels::DocumentoImportacao',
              :foreign_key => 'item_id'

    belongs_to  :cfop,
                :class_name => 'WebNfeFlexModels::Cfop',
                :foreign_key => 'cfop_id'
    # ainda não tem no acras_nfe:
    #belongs_to  :issqn_municipio,
    #            :class_name => 'WebNfeFlexModels::Municipio',
    #            :foreign_key => 'issqn_municipio_id'
    belongs_to  :nota_fiscal,
                :class_name => 'WebNfeFlexModels::NotaFiscal',
                :foreign_key => 'nota_fiscal_id'
    belongs_to  :product,
                :class_name => 'WebNfeFlexModels::Product',
                :foreign_key => 'product_id'

    def descricao_produto
      self.product ? self.product.description : ''
    end

    def descricao_detalhada
      d = self.descricao_produto.strip
      d = "#{d} #{self.detalhe.strip}" if !self.detalhe.blank?
      d
    end

    def values
      result = attributes.clone
      result.symbolize_keys!

      result[:numero_item] = result.delete(:numero)
      result[:ii_despesas_aduaneiras] = result.delete(:ii_valor_despesas_aduaneiras)
      result[:icms_reducao_base_calculo] = result.delete(:icms_porcentual_reducao_base_calculo)
      result[:icms_margem_valor_adicionado_st] = result.delete(:icms_porcentual_margem_valor_adicionado_st)
      result[:icms_reducao_base_calculo_st] = result.delete(:icms_porcentual_reducao_base_calculo_st)

      # ainda não tem no acras_nfe:
      #if !self.issqn_municipio_id.blank?
      #  result[:issqn_codigo_municipio] = self.issqn_municipio.codigo_municipio
      #end

      if self.product
        self.product.values.each do |k, v|
          result[k] = v
        end

        configuracao = self.nota_fiscal.domain.configuracao
        result[:codigo_ncm] = case configuracao.mostrar_ncm
                              when 'nenhum':
                                configuracao.capitulo_ncm.codigo
                              when 'capitulo':
                                if !self.product.capitulo_ncm.blank?
                                  self.product.capitulo_ncm.codigo
                                else
                                  nil
                                end
                              when 'codigo':
                                result[:codigo_ncm]
                              else
                                nil
                              end

        if result[:codigo_produto].blank? && self.cfop
          result[:codigo_produto] = "CFOP#{self.cfop.codigo}"
        end

        result[:descricao] = self.descricao_detalhada
      end

      if self.cfop
        result[:cfop] = self.cfop.codigo
      end

      result[:documentos_importacao] = self.documentos_importacao.collect { |x| x.values }

      [:id, :product_id, :cfop_id, :domain_id, :nota_fiscal_id, :valor_entrada,
          :detalhe, :created_at, :updated_at].each { |x| result.delete(x) }

      result
    end
  end

  class Product < WebNfeFlexModel
    set_table_name 'products'

    belongs_to  :capitulo_ncm,
                :class_name => 'WebNfeFlexModels::CapituloNcm',
                :foreign_key => 'capitulo_ncm_id'

    def values
      { :codigo_produto => code, :descricao => description, :codigo_ncm => codigo_ncm, :codigo_ex_tipi => codigo_ex_tipi,
                 :genero => genero, :unidade_comercial => measurement_unit, :unidade_tributavel => taxable_measurement_unit,
                 :codigo_barras_comercial => valid_barcode, :codigo_barras_tributavel => taxable_barcode
      }
    end

    # barcode válido é apenas GTIN-8, GTIN-12, GTIN-13 ou GTIN-14
    def valid_barcode
      return nil if barcode.blank?
      if [8, 12, 13, 14].include?(barcode.length) && barcode.scan(/\d/).length == barcode.length
        # Ainda não validamos dígito verificador
        barcode
      else
        nil
      end
    end
  end

  class Duplicata < WebNfeFlexModel
    set_table_name 'duplicatas'

    def values
      attrs = attributes.symbolize_keys

      result = {}
      [:numero, :valor, :data_vencimento].each { |x| result[x] = attrs[x] }
      result[:numero] = '0' if result[:numero].blank?

      result
    end
  end

  class DocumentoImportacao < WebNfeFlexModel
    set_table_name 'documentos_importacao'

    has_many  :adicoes,
              :class_name => 'WebNfeFlexModels::Adicao',
              :foreign_key => 'documento_importacao_id'

    def values
      result = attributes.clone
      result.symbolize_keys!

      result[:adicoes] = self.adicoes.collect { |x| x.values }

      result
    end
  end

  class Adicao < WebNfeFlexModel
    set_table_name 'adicoes'

    def values
      result = attributes.clone
      result.symbolize_keys!

      result[:numero_sequencial_item] = result.delete(:numero_sequencial)

      result
    end
  end

  class Volume < WebNfeFlexModel
    set_table_name 'volumes'

    def values
      result = attributes.clone
      result.symbolize_keys!

      result[:numero] = result.delete(:numeracao)
      [:id, :domain_id, :nota_fiscal_id, :created_at, :updated_at].each { |x| result.delete(x) }

      result
    end
  end

  class Referenciada < WebNfeFlexModel
    set_table_name 'referenciadas'

    belongs_to  :referenciada,
                :class_name => 'WebNfeFlexModels::NotaFiscal',
                :foreign_key => :referenciada_id

    def values
      result = attributes.clone
      result.symbolize_keys!

      if self.referenciada
        result[:chave_nfe] = self.referenciada.chave_nfe.gsub(/^NFe/, '')
      elsif !self.chave_externa.blank?
        result[:chave_nfe] = self.chave_externa
      else
        result[:modelo] = '01'
        result[:mes] = '%02d%02d' % [self.ano, self.mes]
        result[:uf] = self.class.codigos_uf_ibge[self.uf]
      end

      result
    end
  end

  class Prestador < WebNfeFlexModel
    set_table_name 'prestadores'
  end

  class CodigoServicoSaoPaulo < WebNfeFlexModel
    set_table_name 'codigos_servico_sao_paulo'
  end

  class NotaFiscalServico < WebNfeFlexModel
    set_table_name 'notas_fiscais_servico'
    # single table inheritance nao funciona aqui :(
    self.inheritance_column = 'non_existing_field'

    belongs_to  :prestador,
                :class_name => 'WebNfeFlexModels::Prestador',
                :foreign_key => 'prestador_id'
    belongs_to  :tomador,
                :class_name => 'WebNfeFlexModels::Person',
                :foreign_key => 'tomador_id'
    belongs_to  :codigo_servico_sao_paulo,
                :class_name => 'WebNfeFlexModels::CodigoServicoSaoPaulo',
                :foreign_key => 'codigo_servico_sao_paulo_id'
  end

  class NotaFiscalSaoPaulo < WebNfeFlexModel
    set_table_name 'notas_fiscais_servico'
    self.inheritance_column = 'non_existing_field'

    belongs_to  :prestador,
                :class_name => 'WebNfeFlexModels::Prestador',
                :foreign_key => 'prestador_id'
    belongs_to  :tomador,
                :class_name => 'WebNfeFlexModels::Person',
                :foreign_key => 'tomador_id'
    belongs_to  :codigo_servico_sao_paulo,
                :class_name => 'WebNfeFlexModels::CodigoServicoSaoPaulo',
                :foreign_key => 'codigo_servico_sao_paulo_id'

    def values
      result = {
        :cnpj_prestador => prestador.cnpj,
        :data_emissao => data_emissao.to_date,
        :tributacao_rps => natureza_operacao,
        :codigo_servico => codigo_servico_sao_paulo.codigo,
        :aliquota_servicos => aliquota/100.0,
        :iss_retido => sao_paulo_iss_retido ? 'true' : 'false',
        :discriminacao => discriminacao
      }
      [:valor_deducoes, :valor_servicos, :valor_pis, :valor_cofins, :valor_inss,
        :valor_csll, :valor_ir].each do |f|
        result[f] = send(f)
        result[f] = 0 if result[f] == 0.0 # senão não valida no xml
      end
      result[:valor_deducoes] ||= 0 # campo obrigatório
      if tomador
        result[:cpf_cnpj_tomador] = {}
        if !tomador.cpf.blank?
          result[:cpf_cnpj_tomador][:cpf] = tomador.cpf
        else
          result[:cpf_cnpj_tomador][:cnpj] = tomador.cnpj
        end
        result[:endereco_tomador] = {
          :logradouro => (tomador.nfe_address.logradouro.blank? ? nil : tomador.nfe_address.logradouro),
          :numero_endereco => (tomador.nfe_address.numero.blank? ? nil : tomador.nfe_address.numero),
          :complemento_endereco => (tomador.nfe_address.complemento.blank? ? nil : tomador.nfe_address.complemento),
          :bairro => (tomador.nfe_address.bairro.blank? ? nil : tomador.nfe_address.bairro),
          :cidade => tomador.nfe_address.municipio.nil? ? nil : tomador.nfe_address.municipio.codigo_municipio,
          :uf => tomador.nfe_address.municipio.nil? ? nil : tomador.nfe_address.municipio.sigla_uf,
          :cep => (tomador.nfe_address.cep.blank? ? nil : tomador.nfe_address.cep)
        }
        result[:inscricao_municipal_tomador] = tomador.inscricao_municipal unless tomador.inscricao_municipal.blank?
        result[:inscricao_estadual_tomador] = tomador.inscricao_estadual unless tomador.inscricao_estadual.blank?
        result[:email_tomador] = tomador.email unless tomador.email.blank?
        result[:razao_social_tomador] = tomador.name
      end
      result
    end
  end

  class AcrasNfeImport < WebNfeFlexModel
    set_table_name 'acras_nfe_imports'
  end

end

