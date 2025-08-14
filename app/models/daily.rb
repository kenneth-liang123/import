# Example model for Daily
class Daily < ApplicationRecord
  has_many :daily_health_pillars, dependent: :destroy
  has_many :health_pillars, through: :daily_health_pillars

  validates :unleash_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :effort, presence: true, numericality: { in: 1..5 }

  # Rails 8 serialization syntax with explicit coder
  serialize :tools, coder: JSON
end
