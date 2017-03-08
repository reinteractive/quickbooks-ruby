module Quickbooks
  module Model
    class Report < BaseModel

      attr_accessor :xml

      # Returns a flat array of all rows
      def all_rows
        @all_rows ||= xml.css("ColData:first-child").map {|node| parse_row(node.parent) }
      end

      # Returns a hash of all rows with :data as the account name, or value and :id if present
      def all_data
        @all_data ||= xml.css("ColData:first-child").map {|node| hash_from_row(node.parent) }
      end

      # Returns the column names as an ordered array
      #
      # Given:
      #   <Columns type="Data">
      #     <Column>
      #       <ColTitle value="" />
      #       <ColType value="Account" />
      #     </Column
      #     <Column>
      #       <ColTitle value="1234.23" />
      #       <ColType value="Money" />
      #     </Column
      #     <Column>
      #       <ColTitle value="987.65" />
      #       <ColType value="Money" />
      #     </Column
      #   </Columns>
      #
      # Returns:
      #
      # ["", "1234.23", "987.65"]
      def columns
        @columns ||= columns_information.map { |c| c[1] }
      end

      # Returns the column names as an ordered array
      #
      # Given:
      #   <Columns type="Data">
      #     <Column>
      #       <ColTitle value="" />
      #       <ColType value="Account" />
      #     </Column
      #     <Column>
      #       <ColTitle value="Debit" />
      #       <ColType value="Money" />
      #     </Column
      #     <Column>
      #       <ColTitle value="Credit" />
      #       <ColType value="Money" />
      #     </Column
      #   </Columns>
      #
      # Returns:
      #
      # [["Account", ""], ["Money", "Debit"], ["Money", "Credit"]]
      def columns_information
        @columns_information ||= begin
          nodes = xml.css('Column')
          nodes.map do |node|
            [node.at('ColType').content, node.at('ColTitle').content]
          end
        end
      end

      def find_row(label)
        all_rows.find {|r| r[0] == label }
      end

      private

      # Parses the given row:
      #   <Row type="Data">
      #     <ColData value="Checking" id="35"/>
      #     <ColData value="1201.00"/>
      #     <ColData value="200.50"/>
      #   </Row>
      #
      #  To:
      #   ['Checking', BigDecimal(1201.00), BigDecimal(200.50)]
      def parse_row(row_node)
        row_node.elements.map.with_index do |el, i|
          value = el.attr('value')

          if i.zero? # Return the first column as a string, its the label.
            value
          elsif value.blank?
            nil
          else
            BigDecimal(value)
          end
        end
      end

      # Parses the data:
      #   <Columns type="Data">
      #     <Column>
      #       <ColTitle value="" />
      #       <ColType value="Account" />
      #     </Column
      #     <Column>
      #       <ColTitle value="Debit" />
      #       <ColType value="Money" />
      #     </Column
      #     <Column>
      #       <ColTitle value="Credit" />
      #       <ColType value="Money" />
      #     </Column
      #   </Columns>
      #   <Rows>
      #     <Row type="Data">
      #       <ColData value="Checking" id="35"/>
      #       <ColData value="1201.00"/>
      #       <ColData value="200.50"/>
      #     </Row>
      #     <Row type="Data">
      #       <ColData value="Savings" id="39"/>
      #       <ColData value="99.00"/>
      #       <ColData value=""/>
      #     </Row>
      #    </Rows>
      #  To:
      #   [
      #     {id: 35, data: 'Checking'},
      #     {id: "Debit", data: BigDecimal(1201.00)},
      #     {id: "Credit", data: BigDecimal(200.50)}
      #   ],[
      #     {id: 39, data: 'Savings'},
      #     {id: "Debit", data: BigDecimal(99.00)},
      #     {id: "Credit", data: nil}
      #   ]
      def hash_from_row(row_node)
        row_node.elements.map.with_index do |el, i|
          row_value = el.attr('value')
          row_id    = el.attr('id')

          row_hash = {}

          if row_id.present?
            row_hash[:id] = row_id
          end

          case
          when row_value.to_s.match(/\A[\.\d]+\z/)
            row_hash[:data] = BigDecimal(row_value)
          when row_value.present?
            row_hash[:data] = row_value
          else
            row_hash[:data] = nil
          end

          row_hash
        end
      end

    end
  end
end
