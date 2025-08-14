# Example model for HealthPillar
class HealthPillar < ApplicationRecord
  has_many :daily_health_pillars, dependent: :destroy
  has_many :dailies, through: :daily_health_pillars

  validates :name, presence: true, uniqueness: true
end
