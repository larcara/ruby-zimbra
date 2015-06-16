module Zimbra
  class Directory
    def self.search
      DirectoryService.search
    end
  end

  class DirectoryService < HandsoapService
    def search
      xml = invoke("n2:SearchDirectoryRequest") do |message|
          Builder.do_search(message, 50)
      end
      return nil if soap_fault_not_found?
      Parser.get_all_response(xml)
    end

    class Parser < Zimbra::AccountService::Parser

    end

  end

  class Builder
    class << self
      def do_search(message,limitCount)
        message.add 'limit', limitCount
        #message.add 'query', '(|(mail=*luigi*)(cn=*luigi*)(sn=*luigi*)(gn=*luigi*)(displayName=*luigi*)(zimbraMailDeliveryAddress=*luigi*))'
        #message.add 'query', '(mail=*al*)'
        message.add 'query', ''
      end

      def create(message, account)
        message.add 'name', account.name
        message.add 'password', account.password
        A.inject(message, 'zimbraCOSId', account.cos_id)
        account.attributes.each do |k,v|
          A.inject(message, k, v)
        end
      end

      def get_by_id(message, id)
        message.add 'account', id do |c|
          c.set_attr 'by', 'id'
        end
      end

      def get_by_name(message, name)
        message.add 'account', name do |c|
          c.set_attr 'by', 'name'
        end
      end

      def modify(message, account)
        message.add 'id', account.id
        modify_attributes(message, distribution_list)
      end
      def modify_attributes(message, account)
        if account.acls.empty?
          ACL.delete_all(message)
        else
          account.acls.each do |acl|
            acl.apply(message)
          end
        end
        Zimbra::A.inject(node, 'zimbraCOSId', account.cos_id)
        Zimbra::A.inject(node, 'zimbraIsDelegatedAdminAccount', (delegated_admin ? 'TRUE' : 'FALSE'))
      end

      def delete(message, id)
        message.add 'id', id
      end

      def add_alias(message,id,alias_name)
        message.add 'id', id
        message.add 'alias', alias_name
      end
    end
  end

=begin
  class Parser
    class << self
      def get_directory_response(response)
        (response/"//n2:account").map do |node|
          account_response(node)
        end
      end

      def account_response(node)
        id = (node/'@id').to_s
        name = (node/'@name').to_s
        acls = Zimbra::ACL.read(node)
        cos_id = Zimbra::A.read(node, 'zimbraCOSId')
        delegated_admin = Zimbra::A.read(node, 'zimbraIsDelegatedAdminAccount')

        #puts name
        Zimbra::Account.new(:id => id, :name => name, :acls => acls, :cos_id => cos_id, :delegated_admin => delegated_admin)
      end
    end
  end
=end

end