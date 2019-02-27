class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :role
  has_many :notifications,dependent: :destroy
  has_many :orders
  has_many :cart_items, class_name: "Cart"
end
