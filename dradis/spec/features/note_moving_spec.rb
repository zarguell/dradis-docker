require 'rails_helper'

describe 'moving a note', js: true do

  subject { page }

  before do
    login_to_project_as_user

    def create_node(label, parent = nil)
      create(:node, label: label, parent: parent, project: current_project)
    end

    # Tree:
    #
    # - node_0
    #   - node_2
    #     - node_5
    #   - node_3
    # - node_1
    #   - node_4
    @node_0 = create_node('Node 0')
    @node_1 = create_node('Node 1')
    @node_2 = create_node('Node 2', @node_0)
    @node_3 = create_node('Node 3', @node_0)
    @node_4 = create_node('Node 4', @node_1)
    @node_5 = create_node('Node 5', @node_2)

    visit project_node_note_path(current_project, @node_5, current_note)
    click_move_note
  end

  let(:text) { "#[Description]#\nTest Note\n" }
  let(:current_note) { @note = create(:note, text: text, node: @node_5) }

  describe 'moving a note to a different node' do
    let(:attachment) { create(:attachment, filename: 'name with spaces.png', node: @node_5) }
    let(:text) { "#[Description]#\n!/projects/#{current_project.id}/nodes/#{@node_5.id}/attachments/#{attachment.filename}!\n" }

    before do
      # Ensure this works with duplicated attachment
      create(:attachment, filename: 'name with spaces.png', node: @node_1)

      within('#modal_move_note') do
        click_link @node_1.label
        click_submit
      end
    end

    it "should update the note's node_id" do
      expect(current_note.reload.node_id).to eq(@node_1.id)
    end

    it 'should redirect to note show path' do
      expect(current_path).to eq(project_node_note_path(current_project, @node_1, current_note))
    end

    it 'should update the attachment reference to the new node' do
      expect(current_note.reload.content).to include("nodes/#{@node_1.id}")
    end
  end

  describe 'moving a note to a similar node' do
    before do
      within('#modal_move_note') do
        click_link @node_5.label
      end
    end

    it 'should update the node as an invalid selection' do
      expect(find('.invalid-selection').text).to eq(@node_5.label)
    end

    it 'should prevent the submit button from being clicked' do
      expect(page).to have_selector '.btn-primary[disabled]'
    end
  end

  def click_move_note
    within('.actions', match: :first) do
      find('.dots-dropdown').click
      find("a[href='#modal_move_note']").click
    end
  end

  def click_submit
    find('.btn-primary').click
  end

end
