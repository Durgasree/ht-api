class CreateProducts < ActiveRecord::Migration[5.2]
  def change
    create_table :products do |t|
      t.string :name
      t.integer :quantity
      t.float :discount
      t.date :discount_start_date
      t.date :discount_end_date
      t.float :price
      t.integer :organization_id

      t.timestamps
    end
  end
end
