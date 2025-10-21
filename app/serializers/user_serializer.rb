# app/serializers/user_serializer.rb
class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :role, :created_at, :updated_at
  
  def role
    object.role.humanize
  end
end