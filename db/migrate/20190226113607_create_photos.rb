class CreatePhotos < ActiveRecord::Migration[5.2]
  def change
    create_table :photos do |t|
      t.string :imageable_type
      t.integer :imageable_id
      t.string :image
      t.boolean :status

      t.timestamps
    end
  end
end
