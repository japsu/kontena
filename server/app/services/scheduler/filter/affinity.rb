module Scheduler
  module Filter
    class Affinity

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @raise [Scheduler::Error]
      def for_service(service, instance_number, nodes)
        return nodes if service.affinity.nil? || service.affinity.size == 0

        service.affinity.each do |affinity|
          affinity = affinity % [instance_number.to_s]
          key, comparator, value = split_affinity(affinity)

          nodes = nodes.select { |node|
            if key == 'node'
              node_match?(node, comparator, value)
            elsif key == 'service'
              service_match?(node, comparator, value)
            elsif key == 'container'
              container_match?(node, comparator, value)
            elsif key == 'label'
              label_match?(node, comparator, value)
            else
              raise StandardError, "Unknown affinity filter: #{key}"
            end
          }

          if nodes.empty?
            raise Scheduler::Error, "Did not find any nodes for affinity filter: #{affinity}"
          end
        end

        nodes
      end

      # @param [String] affinity
      # @raise [Scheduler::Error] invalid filter
      # @return [Array<(String, String, String)>, NilClass]
      def split_affinity(affinity)
        if match = affinity.match(/^(.+)(==|!=)(.+)/)
          match.to_a[1..-1]
        else
          raise Scheduler::Error, "Invalid affinity filter: #{affinity}"
        end
      end

      # @param [HostNode] node
      # @param [String] compare
      # @param [String] value
      def node_match?(node, compare, value)
        if compare == '=='
          node.name == value
        elsif compare == '!='
          node.name != value
        else
          false
        end
      end

      # @param [HostNode] node
      # @param [String] compare
      # @param [String] value
      def container_match?(node, compare, value)
        container_names = node.containers.map{|c|
          c.labels['io;kontena;container;name'].to_s
        }
        if compare == '=='
          container_names.any?{|n| n == value}
        elsif compare == '!='
          !container_names.any?{|n| n == value}
        end
      end

      # @param [HostNode] node
      # @param [String] compare
      # @param [String] value
      def service_match?(node, compare, value)
        service_names = node.containers.delete_if{|c|
            c.grid_service.nil?
          }.map{|c|
            c.grid_service.name
          }.uniq
        if compare == '=='
          service_names.any?{|n| n == value}
        elsif compare == '!='
          !service_names.any?{|n| n == value}
        end
      end

      # @param [HostNode] node
      # @param [String] compare
      # @param [String] value
      def label_match?(node, compare, value)
        if compare == '=='
          if node.labels.nil?
            return false
          else
            node.labels.include?(value)
          end
        elsif compare == '!='
          if node.labels.nil?
            true
          else
            !node.labels.include?(value)
          end
        else
          false
        end
      end
    end
  end
end
