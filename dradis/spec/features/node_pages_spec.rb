require 'rails_helper'

describe 'node pages' do
  subject { page }

  before do
    login_to_project_as_user
  end

  describe 'creating new nodes' do
    context "when a project doesn't have any nodes yet" do
      it 'says so in the sidebar' do
        visit project_path(current_project)
        within '.main-sidebar' do
          should have_selector '.empty-state', text: "You don't have any nodes yet"
        end
      end
    end

    describe "clicking the '+' button in the 'Nodes' sidebar", js: true do
      before do
        visit project_path(current_project)
        find('.main-sidebar .header a').click
      end

      let(:submit_form) { click_button 'Add' }

      it 'shows a modal for adding a top-level node' do
        expect(page).to have_field :branch_node_label
      end

      describe "submitting the 'new top-level node' form" do
        it 'creates and shows the new node' do
          fill_in :branch_node_label, with: 'My awesome node'
          expect { submit_form }.to change { Node.count }.by(1)
          expect(page).to have_content 'Successfully created node.'
          new_node = Node.last
          expect(current_path).to eq project_node_path(new_node.project, new_node)
        end
      end

      include_examples 'creates an Activity', :create, Node

      example 'adding multiple root nodes' do
        choose 'Add multiple'
        expect(page).to have_no_field :branch_node_label
        expect(page).to have_field :branch_nodes_list

        # Include a blank line to make sure that no node gets created:
        fill_in :branch_nodes_list, with: <<-LIST.strip_heredoc
            node 1

            node_2
                 node with trailing whitespace
          LIST

        expect do
          click_button 'Add'
        end.to change { current_project.nodes.in_tree.count }.by(3) \
          .and change { ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by(3)

        expect(
          ActiveJob::Base.queue_adapter.enqueued_jobs.map { |h|
            h[:job]
          }.last(3)
        ).to include *Array.new(3, ActivityTrackingJob)
        expect(
          ActiveJob::Base.queue_adapter.enqueued_jobs.map { |h1|
            h1[:args].map { |h2| h2['action'] }
          }.flatten.last(3)
        ).to include *Array.new(3, 'create')
        expect(
          ActiveJob::Base.queue_adapter.enqueued_jobs.map { |h1|
            h1[:args].map { |h2| h2['trackable_type'] }
          }.flatten.last(3)
        ).to include *Array.new(3, 'Node')

        expect(current_project.nodes.last(3).map(&:label)).to match_array([
          'node 1',
          'node_2',
          'node with trailing whitespace',
        ])

        # redirects to project root:
        expect(page).to have_selector '.breadcrumb-item.active', text: 'Overview'
      end

      example 'adding multiple root host nodes' do
        choose 'Add multiple'

        fill_in :branch_nodes_list, with: "foo\nbar"
        find('#branch_nodes_icon + .combobox').click
        find('.combobox-option', text: 'Host').click

        expect do
          click_button 'Add'
        end.to change { current_project.nodes.in_tree.count }.by(2)

        expect(
          current_project.nodes.in_tree.last(2).all? { |n| n.type_id == Node::Types::HOST }
        ).to be true
      end
    end

    describe 'adding child nodes to an existing node', :js do
      before do
        visit project_node_path(node.project, node)
        find('[data-behavior~=nodes-more-dropdown]').click
        click_link 'Add subnode'
      end

      let(:node) { create(:node, project: current_project) }

      example 'adding a single node' do
        fill_in 'child_node_label', with: 'My new node'
        expect do
          click_button 'Add'
        end.to change { node.children.count }.by(1)
          .and have_enqueued_job(ActivityTrackingJob).with(
            action: 'create',
            project_id: current_project.id,
            trackable_id: node.children.last.try(:id) || Node.last.id + 1,
            trackable_type: 'Node',
            user_id: @logged_in_as.id
          )

        new_node = node.children.last
        expect(new_node.label).to eq 'My new node'
      end

      example 'adding multiple nodes' do
        choose 'Add multiple'
        expect(page).to have_no_field :child_node_label
        expect(page).to have_field :child_nodes_list

        # Include a blank line to make sure that no node gets created:
        fill_in :child_nodes_list, with: <<-LIST.strip_heredoc
            node 1

            node_2
                 node with trailing whitespace
          LIST

        expect do
          click_button 'Add'
        end.to change { node.children.count }.by(3)
        .and change { ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by(3)

        expect(
          ActiveJob::Base.queue_adapter.enqueued_jobs.map { |h|
            h[:job]
          }.last(3)
        ).to eq Array.new(3, ActivityTrackingJob)
        expect(
          ActiveJob::Base.queue_adapter.enqueued_jobs.map { |h1|
            h1[:args].map { |h2| h2['action'] }
          }.flatten.last(3)
        ).to eq Array.new(3, 'create')
        expect(
          ActiveJob::Base.queue_adapter.enqueued_jobs.map { |h1|
            h1[:args].map { |h2| h2['trackable_type'] }
          }.flatten.last(3)
        ).to eq Array.new(3, 'Node')

        expect(node.children.pluck(:label)).to match_array([
          'node 1',
          'node_2',
          'node with trailing whitespace',
        ])

        # redirects to parent node's page
        expect(page).to have_selector 'ol.breadcrumb > li.active', text: node.label
      end

      example 'adding multiple nodes - submitting a blank textarea' do
        choose 'Add multiple'
        fill_in :child_nodes_list, with: "   \n \n \n    \n "
        click_button 'Add'
        expect(page).to have_content 'Please add at least one node'
      end
    end
  end

  describe "clicking 'rename' on a node", js: true do
    before do
      @node = create(:node, label: 'My node', project: current_project)
      visit project_node_path(@node.project, @node)
      find('[data-behavior~=nodes-more-dropdown]').click
      click_link 'Rename'
    end

    let(:submit_form) { click_button 'Rename' }

    it 'shows a modal to rename the node' do
      should have_content /Rename My node node/i
      should have_field :node_new_label
    end

    describe 'submitting a new name' do
      before { fill_in :node_new_label, with: 'new node name' }

      it "updates the node's name" do
        submit_form
        expect(@node.reload.label).to eq 'new node name'
      end

      it 'creates an Activity' do
        expect { submit_form }.to have_enqueued_job(ActivityTrackingJob).with(
          action: 'update',
          project_id: current_project.id,
          trackable_id: @node.id,
          trackable_type: 'Node',
          user_id: @logged_in_as.id
        )
      end
    end

    describe 'submitting an invalid name' do
      before { fill_in :node_new_label, with: '' }

      it "doesn't update the node's name" do
        expect { submit_form }.not_to change { @node.reload.label }
      end

      include_examples "doesn't create an Activity"
    end
  end

  describe "clicking 'Delete' on a node", js: true do
    before do
      @node = create(:node, label: 'My node', project: current_project)
      visit project_node_path(@node.project, @node)
      find('[data-behavior~=nodes-more-dropdown]').click
      click_link 'Delete'
    end

    it 'shows a modal to rename the node' do
      should have_content(
        'Are you sure you want to delete the "My node" node from your project?'
      )
    end

    describe 'confirming the deletion' do
      let(:submit_form) do
        within '#modal_delete_node' do
          click_link 'Delete'
          expect(current_path).to eq project_path(current_project)
        end
      end

      it 'deletes the node' do
        node_id = @node.id
        submit_form
        expect(current_project.nodes.find_by_id(node_id)).to be_nil
      end

      let(:model) { @node }
      include_examples 'creates an Activity', :destroy
    end
  end

  describe 'show page' do
    before do
      @properties = { foo: 'bar', fizz: 'buzz' }
      @node = create(:node, project: current_project, properties: @properties)
      extra_setup
      visit project_node_path(@node.project, @node)
    end

    let(:extra_setup) { nil }

    context 'when the node has activities' do
      include ActivityMacros

      let(:extra_setup) do
        @note       = create(:note, node: @node)
        @issue      = create(:issue, node: current_project.issue_library)
        @evidence   = create(:evidence, issue: @issue, node: @node)
        @other_node = create(:node, project: current_project)
        @activities = [@node, @note, @evidence].flat_map do |model|
          [
            # TODO: Project singleton
            # create(:create_activity, trackable: model, project: @project),
            create(:create_activity, trackable: model),
            # create(:update_activity, trackable: model,  project: @project)
            create(:update_activity, trackable: model)
          ]
        end
        @other_activity = create(:update_activity, trackable: @other_node)
      end

      it 'lists them in the activity feed' do
        within activity_feed do
          @activities.each do |activity|
            should have_activity(activity)
          end
          should_not have_activity(@other_activity)
        end
      end
    end

    context 'when the node has no recent activity' do
      it { should have_content "You don't have any activities yet" }
    end

    context 'when the node has nested notes or evidence' do
      let(:extra_setup) do
        @note           = create(:note, node: @node, text: "#[Title]#\nMy note")
        @issue          = create(:issue, node: current_project.issue_library)
        @evidence       = create(:evidence, issue: @issue, node: @node)
        other_node      = create(:node, project: current_project)
        @other_note     = create(:note,     node: other_node)
        @other_evidence = create(:evidence, node: other_node)
      end

      it 'lists them in the sidebar' do
        within '.secondary-sidebar' do
          should have_selector "#note_#{@note.id}_link", text: 'My note'
          should have_selector "#evidence_#{@evidence.id}_link"
          should_not have_selector "#note_#{@other_note.id}_link"
          should_not have_selector "#evidence_#{@other_evidence.id}_link"
        end
      end
    end

    it "shows the node's properties" do
      @properties.each do |key, value|
        should have_selector 'h4', text: key.to_s.capitalize
        should have_selector 'p',  text: value
      end
    end
  end

  describe 'edit page' do
    before do
      @properties = { foo: 'bar', fizz: 'buzz' }
      @node = create(:node, label: 'My node', project: current_project, properties: @properties)
      extra_setup
      visit edit_project_node_path(@node.project, @node)
    end

    let(:extra_setup) { nil }
    let(:submit_form) { click_button 'Update Node' }

    it "has a form to edit the node's properties" do
      should have_field :node_raw_properties
      expect(
        find('#node_raw_properties').text.squish
      ).to eq @node.raw_properties.squish
    end

    describe 'when this node is not a root node' do
      let(:extra_setup) do
        @node.parent = create(:node, label: 'Parent', project: current_project)
        @node.save!
      end

      it 'shows the current node in the sidebar node tree', js: true do
        within ".main-sidebar .nodes-nav #node_#{@node.id}" do
          expect(page).to have_content 'My node'
        end
      end
    end

    describe 'submitting the form with valid information' do
      before do
        # fill_in :node_raw_properties doesn't work for some reason :(
        find('#node_raw_properties').set('{ "hello" : "hola" }')
      end

      it "updates the node's properties" do
        submit_form
        expect(@node.reload.properties).to eq({ 'hello' => 'hola' })
      end

      it "redirects to the node's show page" do
        submit_form
        expect(current_path).to eq project_node_path(@node.project, @node)
      end

      let(:model) { @node }
      include_examples 'creates an Activity', :update
    end

    describe 'submitting the form with invalid information' do
      before do
        # invalid JSON:
        find('#node_raw_properties').set('{ "hello" "hola" }')
      end

      it "doesn't update the node's properties" do
        expect { submit_form }.not_to change { @node.reload.properties }
      end

      # UPGRADE: fix specs
      # include_examples "doesn't create an Activity"
    end
  end
end
