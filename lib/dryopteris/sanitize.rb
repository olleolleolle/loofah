require 'cgi'

module Dryopteris

  module SanitizerInstanceMethods

    def sanitize(*args)
      method = args.first
      case method
      when :escape, :prune, :whitewash
        __sanitize_roots.each do |node|
          Sanitizer.traverse_conditionally_top_down(node, method.to_sym)
        end
      when :yank
        __sanitize_roots.each do |node|
          Sanitizer.traverse_conditionally_bottom_up(node, method.to_sym)
        end
      else
        raise ArgumentError, "unknown sanitize filter '#{method}'"
      end
      self
    end

  end

  module Sanitizer
    class << self

      def sanitize(node)
        case node.type
        when Nokogiri::XML::Node::ELEMENT_NODE
          if HTML5::HashedWhiteList::ALLOWED_ELEMENTS[node.name]
            HTML5::Scrub.scrub_attributes node
            return false
          end
        when Nokogiri::XML::Node::TEXT_NODE, Nokogiri::XML::Node::CDATA_SECTION_NODE
          return false
        end
        true
      end

      def escape(node)
        return false unless sanitize(node)
        replacement_killer = Nokogiri::XML::Text.new(node.to_s, node.document)
        node.add_next_sibling replacement_killer
        node.remove
        return true
      end

      def prune(node)
        return false unless sanitize(node)
        node.remove
        return true
      end

      def yank(node)
        return false unless sanitize(node)
        replacement_killer = node.before node.inner_html
        node.remove
        return true
      end

      def whitewash(node)
        case node.type
        when Nokogiri::XML::Node::ELEMENT_NODE
          if HTML5::HashedWhiteList::ALLOWED_ELEMENTS[node.name]
            node.attributes.each { |attr| node.remove_attribute(attr.first) }
            return false if node.namespaces.empty?
          end
        when Nokogiri::XML::Node::TEXT_NODE, Nokogiri::XML::Node::CDATA_SECTION_NODE
          return false
        end
        node.remove
        return true
      end

      def traverse_conditionally_top_down(node, method_name)
        return if send(method_name, node)
        node.children.each {|j| traverse_conditionally_top_down(j, method_name)}
      end

      def traverse_conditionally_bottom_up(node, method_name)
        node.children.each {|j| traverse_conditionally_bottom_up(j, method_name)}
        return if send(method_name, node)
      end

    end

  end
end


module Dryopteris

  class << self
    def strip_tags(string_or_io, encoding=nil)
      Dryopteris::HTML::Document.parse(string_or_io, nil, encoding).sanitize(:prune).inner_text
    end
    
    def whitewash(string, encoding=nil)
      Dryopteris::HTML::DocumentFragment.parse(string).sanitize(:whitewash).to_xml
    end

    def whitewash_document(string_or_io, encoding=nil)
      Dryopteris::HTML::Document.parse(string_or_io, nil, encoding).sanitize(:whitewash).xpath('/html/body').first.children.to_html
    end

    def sanitize(string, encoding=nil)
      Dryopteris::HTML::DocumentFragment.parse(string).sanitize(:escape).to_xml
    end
    
    def sanitize_document(string_or_io, encoding=nil)
      Dryopteris::HTML::Document.parse(string_or_io, nil, encoding).sanitize(:escape).xpath('/html/body').first.children.to_xml
    end

  end # self

end
