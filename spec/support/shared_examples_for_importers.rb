RSpec.shared_examples 'an importer' do
  it 'inherits from BaseImporter' do
    expect(described_class.superclass).to eq(Importer::BaseImporter)
  end

  it 'responds to import method' do
    expect(subject).to respond_to(:import)
  end

  it 'has filepath attribute' do
    expect(subject).to respond_to(:filepath)
  end

  it 'has errors attribute' do
    expect(subject).to respond_to(:errors)
    expect(subject.errors).to be_an(Array)
  end

  it 'has test_mode_enabled attribute' do
    expect(subject).to respond_to(:test_mode_enabled)
  end
end

RSpec.shared_examples 'csv header validation' do |required_headers|
  context 'when required headers are missing' do
    let(:incomplete_csv) do
      # Create CSV with only some headers
      headers = required_headers.first(2)
      "#{headers.join(',')}\n1,value1"
    end

    before do
      File.write(filepath, incomplete_csv)
    end

    it 'adds appropriate error messages' do
      subject.send(:import)
      expect(subject.errors).not_to be_empty
      expect(subject.errors.first).to include('Required headers missing')
    end

    it 'does not process CSV rows when headers are missing' do
      expect(CSV).not_to receive(:foreach).with(filepath, headers: true)
      subject.send(:import)
    end
  end
end

RSpec.shared_examples 'csv processing' do
  it 'reads CSV file with headers' do
    expect(CSV).to receive(:foreach).with(filepath, headers: true).and_call_original
    subject.send(:import)
  end

  it 'handles CSV parsing errors gracefully' do
    # Write malformed CSV
    File.write(filepath, "header1,header2\nvalue1,\"unclosed quote")

    expect { subject.send(:import) }.not_to raise_error
  end
end

RSpec.shared_examples 'test mode behavior' do
  context 'in test mode' do
    subject { described_class.new(filepath, test_mode_enabled: true) }

    it 'does not perform database operations' do
      # This should be customized per importer to test specific database operations
      expect { subject.import }.not_to raise_error
    end
  end

  context 'in production mode' do
    subject { described_class.new(filepath, test_mode_enabled: false) }

    it 'performs database operations' do
      # This should be customized per importer to test specific database operations
      expect { subject.import }.not_to raise_error
    end
  end
end
