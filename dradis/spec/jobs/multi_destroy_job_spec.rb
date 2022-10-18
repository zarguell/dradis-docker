require 'rails_helper'

describe MultiDestroyJob do #, type: :job do

  it 'uses correct queue' do
    expect(described_class.new.queue_name).to eq('dradis_project')
  end

  describe '#perform' do
    before do
      @project = create(:project)
      @user    = create(:user)
      node     = create(:node, project: @project)
      PaperTrail.request.controller_info = { project_id: @project.id }
      @notes = [
        create(:note, node: node),
        create(:note, node: node),
        create(:note, node: node)
      ]

      described_class.new.perform(
        author_email: @user.email,
        ids: @notes.map(&:id),
        klass: 'Note',
        project_id: @project.id,
        uid: 1
      )
    end

    it 'deletes the items' do
      expect(Note.where(id: @notes.map(&:id))).to be_empty
    end

    it 'writes a known final line in the log' do
      expect(Log.last.text).to eq 'Worker process completed.'
    end
  end
end
