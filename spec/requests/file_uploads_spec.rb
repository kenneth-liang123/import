require 'rails_helper'

RSpec.describe "FileUploads", type: :request do
  describe "GET /file_uploads" do
    it "returns http success" do
      get "/file_uploads"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /file_uploads" do
    it "handles file upload request" do
      post "/file_uploads", params: {
        file_upload: {
          file_type: 'dailies',
          import_type: 'import'
        }
      }
      # Should redirect or show validation errors
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

end
