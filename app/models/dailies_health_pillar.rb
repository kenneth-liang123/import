# Example join model for DailiesHealthPillar
class DailiesHealthPillar < ApplicationRecord
  belongs_to :daily
  belongs_to :health_pillar

  validates :quartile, presence: true, numericality: { in: 1..4 }
  validates :daily_id, uniqueness: { scope: :health_pillar_id }
end
