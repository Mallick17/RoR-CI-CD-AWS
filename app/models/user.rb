class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  # has_one_attached :avatar
  has_one_attached :avatar, dependent: :destroy do |attachable|
    attachable.variant :thumb, resize_to_limit: [50, 50]
    attachable.variant :profile, resize_to_limit: [150, 150]
  end
  has_many :messages, dependent: :destroy
  has_many :conversations, foreign_key: :sender_id
  validates :first_name, presence: :true
  validates :last_name, presence: :true
  def self.full_name(current_user="")
  	if current_user.present?
	    current_user.first_name + " " + current_user.last_name
    else
      current_user.email
	  end
  end
end
