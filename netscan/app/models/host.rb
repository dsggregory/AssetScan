class Host < ActiveRecord::Base
  has_many :ports
  has_many :issues
end
