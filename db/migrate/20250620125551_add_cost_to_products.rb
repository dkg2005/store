class AddCostToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :cost, :decimal
  end
end
