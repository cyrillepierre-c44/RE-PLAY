class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :lockable, :timeoutable

  def active_for_authentication?
    super && !disabled?
  end

  def inactive_message
    disabled? ? :disabled : super
  end
end
