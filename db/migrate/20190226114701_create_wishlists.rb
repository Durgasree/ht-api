class CreateWishlists < ActiveRecord::Migration[5.2]
  def change
    create_table :wishlists do |t|
      t.integer :product_id
      t.integer :user_id
      t.boolean :status

      t.timestamps
    end
  end
end
