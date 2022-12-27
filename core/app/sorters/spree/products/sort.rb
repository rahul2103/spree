module Spree
  module Products
    class Sort < ::Spree::BaseSorter
      def initialize(scope, current_currency, params = {}, allowed_sort_attributes = [])
        super(scope, params, allowed_sort_attributes)
        @currency = params[:currency] || current_currency
      end

      def call
        products = by_param_attributes(scope)
        products = by_price(products)
        products = by_sku(products)

        products = select_translatable_fields(products)

        products.distinct
      end

      private

      attr_reader :sort, :scope, :currency, :allowed_sort_attributes

      def by_price(scope)
        return scope unless (value = sort_by?('price'))

        scope.joins(master: :prices).
          select("#{Spree::Product.table_name}.*, #{Spree::Price.table_name}.amount").
          distinct.
          where(spree_prices: { currency: currency }).
          order("#{Spree::Price.table_name}.amount #{value[1]}")
      end

      def by_sku(scope)
        return scope unless (value = sort_by?('sku'))

        select_product_attributes = if scope.to_sql.include?("#{Spree::Product.table_name}.*")
                                      ''
                                    else
                                      "#{Spree::Product.table_name}.*, "
                                    end

        scope.joins(:master).
          select("#{select_product_attributes}#{Spree::Variant.table_name}.sku").
          where(Spree::Variant.table_name.to_s => { is_master: true }).
          order("#{Spree::Variant.table_name}.sku #{value[1]}")
      end

      def sort_by?(field)
        sort.detect { |s| s[0] == field }
      end

      # Add translatable fields to SELECT statement to avoid InvalidColumnReference error (Mobility bug workaround)
      def select_translatable_fields(scope)
        sql_fields = translatable_sortable_fields
        return scope if sql_fields.empty?

        # if sorting by 'sku' or 'price', spree_products.* is already included in SELECT statement
        if sort_by?('sku') || sort_by?('price')
          scope.i18n.select(sql_fields)
        else
          scope.i18n.select("#{Product.table_name}.*, #{sql_fields}")
        end
      end

      def translatable_sortable_fields
        fields = []
        Product.translatable_fields.each do |field|
          fields << field if sort_by?(field.to_s)
        end

        fields.map { |field| "#{Product.translation_table_alias}.#{field} AS translation_#{field}" }.
          join(', ')
      end
    end
  end
end
