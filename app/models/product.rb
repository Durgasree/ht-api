class Product < ApplicationRecord
  has_many :product_images
  has_many :images, through: :product_images
  has_many :order_products
  has_many :orders,through: :order_products
  has_one :organization
  
end
