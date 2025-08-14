# Example model for HealthPillar
class HealthPillar < ApplicationRecord
  has_many :dailies_health_pillars, dependent: :destroy
  has_many :dailies, through: :dailies_health_pillars

  validates :name, presence: true, uniqueness: true
end
