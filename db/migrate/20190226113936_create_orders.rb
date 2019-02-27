class CreateOrders < ActiveRecord::Migration[5.2]
  def change
    create_table :orders do |t|
      t.float :amount
      t.float :discount
      t.float :final_amount
      t.text :address
      t.string :phone
      t.string :payment_status
      t.string :status
      t.string :tracking_status
      t.integer :user_id
      t.timestamps
    end
  end
end
