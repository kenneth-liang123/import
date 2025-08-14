# 📊 MyApp - Excel/CSV File Upload & Processing System

A modern Rails 8 application that provides a beautiful interface for content creators to upload Excel and CSV files for importing dailies and health pillar data. Features background processing with Sidekiq, comprehensive testing, and a stunning Tailwind CSS interface.

## ✨ Features

- 🎨 **Beautiful UI**: Modern, responsive interface built with Tailwind CSS v4
- 📁 **File Upload**: Drag & drop Excel (.xlsx, .xls) and CSV file uploads
- ⚙️ **Background Processing**: Sidekiq-powered background job processing
- 📊 **Data Import**: Support for dailies and daily-health-pillar data
- 🔄 **Import Options**: Choose between "Import New Only" or "Import & Update" modes
- 📈 **Progress Tracking**: Real-time status updates and processing history
- 🔄 **Retry Functionality**: Automatic retry for failed uploads
- 🧪 **Comprehensive Testing**: 104+ RSpec tests with full coverage
- 📱 **Responsive Design**: Works perfectly on desktop, tablet, and mobile

## 🛠️ Technology Stack

- **Ruby**: 3.4.2
- **Rails**: 8.0.2
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq 8.0.7 with Redis
- **Frontend**: Tailwind CSS v4.1.11
- **File Processing**: Roo gem for Excel files
- **Testing**: RSpec 3.13
- **File Storage**: Active Storage (local disk in development)

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- **Ruby 3.4.2** (use rbenv, rvm, or similar)
- **PostgreSQL** (v12 or higher)
- **Redis** (for Sidekiq background jobs)
- **Node.js** (for Tailwind CSS compilation)
- **Git**

### Installing Prerequisites

#### macOS (using Homebrew)
```bash
# Install Homebrew if you haven't already
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install postgresql redis node
brew services start postgresql
brew services start redis

# Install Ruby 3.4.2 (using rbenv)
brew install rbenv
rbenv install 3.4.2
rbenv global 3.4.2
```

#### Ubuntu/Debian
```bash
# Update packages
sudo apt update

# Install dependencies
sudo apt install postgresql postgresql-contrib redis-server nodejs npm
sudo systemctl start postgresql
sudo systemctl start redis-server

# Install Ruby 3.4.2 (using rbenv)
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
rbenv install 3.4.2
rbenv global 3.4.2
```

## 🚀 Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd myapp
```

### 2. Install Ruby Dependencies
```bash
# Install bundler if you haven't already
gem install bundler

# Install gems
bundle install
```

### 3. Database Setup
```bash
# Create databases
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Seed sample data (optional)
bin/rails db:seed
```

### 4. Environment Configuration
Create a `.env` file in the root directory:
```bash
# .env
REDIS_URL=redis://localhost:6379/0
```

### 5. Install and Build Assets
```bash
# Tailwind CSS is automatically compiled with bin/dev
# No separate installation needed
```

## 🏃‍♂️ Running the Application

### Development Mode
```bash
# Start the development server with Tailwind CSS watching
bin/dev
```

This command starts:
- Rails server on `http://localhost:3000`
- Tailwind CSS compiler with file watching

### Alternative: Manual Setup
If you prefer to run services separately:

```bash
# Terminal 1: Start Rails server
bin/rails server

# Terminal 2: Start Tailwind CSS compiler
bin/rails tailwindcss:watch

# Terminal 3: Start Sidekiq for background jobs
bundle exec sidekiq
```

### Production Mode
```bash
# Precompile assets
bin/rails assets:precompile

# Start the server
bin/rails server -e production
```

## 🧪 Running Tests

### Run All Tests
```bash
bundle exec rspec
```

### Run Specific Test Files
```bash
# Test models
bundle exec rspec spec/models/

# Test jobs
bundle exec rspec spec/jobs/

# Test controllers
bundle exec rspec spec/controllers/

# Run with documentation format
bundle exec rspec --format documentation
```

### Test Coverage
The application includes comprehensive tests covering:
- Model validations and methods
- Background job processing
- Controller actions
- File upload functionality
- Data import logic

## 📁 File Upload Instructions

### Supported Formats
- **Excel**: `.xlsx`, `.xls`
- **CSV**: `.csv`

### Data Types
1. **Dailies**: Import daily activities and routines
   - Expected columns: `date`, `activity`, `category`, etc.
2. **Health Pillars**: Import daily-health pillar relationships
   - Expected columns: `daily_id`, `health_pillar_id`, etc.

### Import Modes
- **Import New Only**: Adds new records, skips existing ones (safest option)
- **Import & Update**: Adds new records and updates existing ones

### Sample Files
Sample CSV files are included in the project:
- `example_dailies.csv` - Sample dailies data
- `example_daily_health_pillars.csv` - Sample health pillar data

## 🎯 Usage Guide

### Application Flow

```mermaid
flowchart TD
    A[User visits Home Page] --> B[Click File Upload Center]
    B --> C[File Upload Interface]
    C --> D{Select File}
    D --> E[Choose Data Type]
    E --> F{Dailies or Health Pillars?}
    F -->|Dailies| G[Select Import Mode: New Only vs Update]
    F -->|Health Pillars| G
    G --> H[Submit Form]
    H --> I{File Validation}
    I -->|Invalid| J[Show Error Messages]
    I -->|Valid| K[Save FileUpload Record]
    J --> C
    K --> L[Enqueue ProcessExcelFileJob]
    L --> M[Background Processing Starts]
    M --> N{File Type Check}
    N -->|Excel| O[Convert Excel to CSV]
    N -->|CSV| P[Process CSV Directly]
    O --> P
    P --> Q{Data Type?}
    Q -->|Dailies| R[Enqueue ImportDailiesJob]
    Q -->|Health Pillars| S[Enqueue ImportDailyHealthPillarsJob]
    R --> T[Import/Update Data in Database]
    S --> T
    T --> U{Success?}
    U -->|Yes| V[Update Status: Completed]
    U -->|No| W[Update Status: Failed + Error Message]
    V --> X[User sees Success in UI]
    W --> Y[User sees Error + Retry Option]
    Y --> Z[Click Retry]
    Z --> L
    X --> END[Process Complete]
```

### Database Design

```mermaid
erDiagram
    FILE_UPLOADS {
        bigint id PK
        string filename
        string file_type "dailies or daily_health_pillars"
        string import_type "import or update"
        string status "pending, processing, completed, failed"
        string user_email "nullable"
        string job_id "Sidekiq job ID"
        text error_message "nullable"
        timestamp processed_at "nullable"
        timestamp created_at
        timestamp updated_at
    }
    
    ACTIVE_STORAGE_BLOBS {
        bigint id PK
        string key
        string filename
        string content_type
        text metadata
        string service_name
        bigint byte_size
        string checksum
        timestamp created_at
    }
    
    ACTIVE_STORAGE_ATTACHMENTS {
        bigint id PK
        string name
        string record_type
        bigint record_id FK
        bigint blob_id FK
        timestamp created_at
    }
    
    DAILIES {
        bigint id PK
        date date
        string activity
        string category
        text description "nullable"
        timestamp created_at
        timestamp updated_at
    }
    
    HEALTH_PILLARS {
        bigint id PK
        string name
        text description "nullable"
        timestamp created_at
        timestamp updated_at
    }
    
    DAILY_HEALTH_PILLARS {
        bigint id PK
        bigint daily_id FK
        bigint health_pillar_id FK
        decimal rating "nullable"
        text notes "nullable"
        timestamp created_at
        timestamp updated_at
    }
    
    FILE_UPLOADS ||--o| ACTIVE_STORAGE_ATTACHMENTS : "has_one_attached file"
    ACTIVE_STORAGE_ATTACHMENTS ||--|| ACTIVE_STORAGE_BLOBS : "belongs_to blob"
    DAILIES ||--o{ DAILY_HEALTH_PILLARS : "has_many"
    HEALTH_PILLARS ||--o{ DAILY_HEALTH_PILLARS : "has_many"
    DAILY_HEALTH_PILLARS }o--|| DAILIES : "belongs_to daily"
    DAILY_HEALTH_PILLARS }o--|| HEALTH_PILLARS : "belongs_to health_pillar"
```

### Job Processing Flow

```mermaid
sequenceDiagram
    participant U as User
    participant C as Controller
    participant M as FileUpload Model
    participant S as Sidekiq
    participant PJ as ProcessExcelFileJob
    participant IJ as ImportJob
    participant DB as Database
    
    U->>C: Upload file
    C->>M: Create FileUpload record
    M->>DB: Save with status: pending
    C->>S: Enqueue ProcessExcelFileJob
    S->>PJ: Execute job
    
    Note over PJ: File Processing
    PJ->>M: Update status: processing
    PJ->>PJ: Validate file format
    PJ->>PJ: Convert Excel to CSV (if needed)
    PJ->>S: Enqueue appropriate ImportJob
    
    Note over IJ: Data Import
    S->>IJ: Execute ImportJob
    IJ->>IJ: Parse CSV data
    IJ->>IJ: Validate data format
    
    alt Import Mode: New Only
        IJ->>DB: Insert new records only
    else Import Mode: Update
        IJ->>DB: Insert new + Update existing
    end
    
    alt Success
        IJ->>M: Update status: completed
        IJ->>M: Set processed_at timestamp
    else Failure
        IJ->>M: Update status: failed
        IJ->>M: Set error_message
    end
    
    M->>DB: Save final status
    U->>C: Check upload status
    C->>M: Fetch current status
    M->>U: Display current status
```

### 1. Access the Application
Open your browser and navigate to `http://localhost:3000`

### 2. Upload Files
1. Click on "File Upload Center" from the home page
2. Drag and drop your file or click to browse
3. Select the data type (Dailies or Health Pillars)
4. Choose import behavior (Import New or Import & Update)
5. Click "🚀 Upload & Process File"

### 3. Monitor Progress
- View upload status in real-time
- Check processing history in the Recent Uploads table
- Click "View" to see detailed upload information
- Use "Retry" for failed uploads

### 4. Background Processing
Files are processed in the background using Sidekiq:
- Navigate to `http://localhost:3000/sidekiq` to monitor jobs
- View job statistics, retries, and failures
- Process queues and scheduled jobs

## 📂 Project Structure

```
myapp/
├── app/
│   ├── controllers/
│   │   ├── file_uploads_controller.rb    # File upload handling
│   │   └── home_controller.rb            # Home page
│   ├── jobs/
│   │   ├── process_excel_file_job.rb     # File processing job
│   │   ├── import_dailies_job.rb         # Dailies import
│   │   └── import_daily_health_pillars_job.rb
│   ├── models/
│   │   └── file_upload.rb                # File upload model
│   ├── views/
│   │   ├── file_uploads/                 # Upload interface
│   │   └── home/                         # Home page
│   └── assets/
├── config/
│   ├── routes.rb                         # Application routes
│   ├── database.yml                      # Database configuration
│   └── initializers/
├── db/
│   └── migrate/                          # Database migrations
├── spec/                                 # RSpec tests
└── storage/                              # File uploads (development)
```

## 🔧 Configuration

### Database Configuration
Edit `config/database.yml` to customize database settings:
```yaml
development:
  adapter: postgresql
  database: myapp_development
  username: your_username  # Add if needed
  password: your_password  # Add if needed
  host: localhost
  port: 5432
```

### Sidekiq Configuration
Configure Redis connection in `config/initializers/sidekiq.rb`:
```ruby
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
```

### Environment Variables
Create a `.env` file for local development:
```bash
REDIS_URL=redis://localhost:6379/0
DATABASE_URL=postgresql://username:password@localhost/myapp_development
```

## 🚨 Troubleshooting

### Common Issues

#### PostgreSQL Connection Issues
```bash
# Start PostgreSQL service
brew services start postgresql  # macOS
sudo systemctl start postgresql  # Linux

# Create user if needed
createuser -s your_username
```

#### Redis Connection Issues
```bash
# Start Redis service
brew services start redis  # macOS
sudo systemctl start redis-server  # Linux

# Test Redis connection
redis-cli ping  # Should return PONG
```

#### Permission Issues
```bash
# Fix bundle permissions
bundle install --path vendor/bundle
```

#### Asset Compilation Issues
```bash
# Clear asset cache
bin/rails assets:clobber
bin/rails assets:precompile
```

### Database Issues
```bash
# Reset database
bin/rails db:drop db:create db:migrate db:seed

# Check migrations
bin/rails db:migrate:status
```

