# Sample Data Creator for Testing File Uploads
# This script creates sample CSV files for testing the upload functionality

require 'csv'

# Create sample dailies CSV file
csv_content = <<~CSV
unleash id,daily_name,description,duration_minutes,effort,category,step_by_step_guide,scientific_explanation,detailed health benefit,guide,tools
1,Morning Meditation,Start your day with mindfulness,15,2,Mental Wellness,1. Find quiet space 2. Sit comfortably 3. Focus on breathing,Meditation reduces cortisol levels,Reduces stress and anxiety,Use guided meditation apps,Meditation app
2,Evening Walk,Light cardio exercise,30,3,Physical Activity,1. Put on comfortable shoes 2. Choose safe route 3. Walk at moderate pace,Walking improves cardiovascular health,Strengthens heart and improves circulation,Plan safe walking routes,Walking shoes
3,Gratitude Journal,Reflect on positive experiences,10,1,Mental Wellness,1. Get notebook 2. Write 3 things you're grateful for,Gratitude practices increase happiness,Improves mental wellbeing and outlook,Keep journal by bedside,Journal and pen
4,Hydration Check,Monitor daily water intake,2,1,Physical Activity,1. Check water bottle 2. Drink if needed 3. Refill bottle,Proper hydration supports all body functions,Maintains energy and cognitive function,Set reminders on phone,Water bottle
CSV

File.write('tmp/sample_dailies.csv', csv_content)
puts "Created sample_dailies.csv"

# Create sample health pillars CSV file
health_pillars_content = <<~CSV
unleash id,Physical,Mental,Emotional,Social
1,0,1,1,0
2,1,0,0,1
3,0,1,1,1
4,1,0,0,0
CSV

File.write('tmp/sample_health_pillars.csv', health_pillars_content)
puts "Created sample_health_pillars.csv"

puts "\nSample files created in tmp/ directory:"
puts "- tmp/sample_dailies.csv (for testing dailies import)"
puts "- tmp/sample_health_pillars.csv (for testing health pillars import)"
puts "\nYou can upload these files through the web interface at http://localhost:3001/file_uploads"
