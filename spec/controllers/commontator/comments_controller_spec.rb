require 'rails_helper'
require 'acts_as_votable'

module Commontator
  RSpec.describe CommentsController, type: :controller do
    routes { Commontator::Engine.routes }

    before(:each) do
      setup_controller_spec
      @comment = Comment.new
      @comment.thread = @thread
      @comment.creator = @user
      @comment.body = 'Something'
      @comment.save!
      expect(@comment.is_votable?).to eq true
    end

    it "won't get new unless authorized" do
      get :new, :thread_id => @thread.id
      expect(response).to have_http_status(:forbidden)

      sign_in @user
      get :new, :thread_id => @thread.id
      expect(response).to have_http_status(:forbidden)
    end

    it 'must get new if authorized' do
      sign_in @user

      @user.can_read = true
      get :new, :thread_id => @thread.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty

      @user.can_read = false
      @user.can_edit = true
      get :new, :thread_id => @thread.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty

      @user.can_edit = false
      @user.is_admin = true
      get :new, :thread_id => @thread.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
    end

    it "won't create unless authorized" do
      attributes = Hash.new
      attributes[:body] = 'Something else'

      post :create, :thread_id => @thread.id, :comment => attributes
      expect(response).to have_http_status(:forbidden)

      sign_in @user
      post :create, :thread_id => @thread.id, :comment => attributes
      expect(response).to have_http_status(:forbidden)

      @user.can_read = true
      @user.can_edit = true
      @user.is_admin = true
      expect(@thread.close).to eq true
      post :create, :thread_id => @thread.id, :comment => attributes
      expect(response).to have_http_status(:forbidden)
    end

    it 'must create if authorized' do
      sign_in @user
      attributes = Hash.new

      attributes[:body] = 'Something else'
      @user.can_read = true
      post :create, :thread_id => @thread.id, :comment => attributes
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).body).to eq 'Something else'
      expect(assigns(:comment).creator).to eq @user
      expect(assigns(:comment).editor).to be_nil
      expect(assigns(:comment).thread).to eq @thread

      attributes[:body] = 'Another thing'
      @user.can_read = false
      @user.can_edit = true
      post :create, :thread_id => @thread.id, :comment => attributes
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).body).to eq 'Another thing'
      expect(assigns(:comment).creator).to eq @user
      expect(assigns(:comment).editor).to be_nil
      expect(assigns(:comment).thread).to eq @thread

      attributes[:body] = 'And this too'
      @user.can_edit = false
      @user.is_admin = true
      post :create, :thread_id => @thread.id, :comment => attributes
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).body).to eq 'And this too'
      expect(assigns(:comment).creator).to eq @user
      expect(assigns(:comment).editor).to be_nil
      expect(assigns(:comment).thread).to eq @thread
    end

    it "won't create if double posting" do
      sign_in @user
      @user.can_read = true
      attributes = Hash.new

      attributes[:body] = 'Something'
      post :create, :thread_id => @thread.id, :comment => attributes
      assert_redirected_to @thread
      expect(assigns(:comment).errors).not_to be_empty

      attributes[:body] = 'Something else'
      post :create, :thread_id => @thread.id, :comment => attributes
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).body).to eq 'Something else'
      expect(assigns(:comment).creator).to eq @user
      expect(assigns(:comment).editor).to be_nil
      expect(assigns(:comment).thread).to eq @thread

      attributes[:body] = 'Something else'
      post :create, :thread_id => @thread.id, :comment => attributes
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).not_to be_empty
    end

    it "won't edit unless authorized" do
      get :edit, :id => @comment.id
      expect(response).to have_http_status(:forbidden)

      sign_in @user
      get :edit, :id => @comment.id
      expect(response).to have_http_status(:forbidden)

      user2 = DummyUser.create
      user2.can_read = true
      user2.can_edit = true
      user2.is_admin = true
      sign_in user2
      get :edit, :id => @comment.id
      expect(response).to have_http_status(:forbidden)

      @user.can_read = true
      @user.can_edit = true
      @user.is_admin = true
      sign_in @user
      comment2 = Comment.new
      comment2.thread = @thread
      comment2.creator = @user
      comment2.body = 'Something else'
      comment2.save!
      get :edit, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
    end

    it 'must edit if authorized' do
      sign_in @user

      @user.can_read = true
      get :edit, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty

      @user.can_read = false
      @user.can_edit = true
      get :edit, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty

      @user.can_edit = false
      @user.is_admin = true
      get :edit, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
    end

    it "won't update unless authorized" do
      attributes = Hash.new
      attributes[:body] = 'Something else'

      put :update, :id => @comment.id, :comment => attributes
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.body).to eq 'Something'
      expect(@comment.editor).to be_nil

      sign_in @user
      put :update, :id => @comment.id, :comment => attributes
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.body).to eq 'Something'
      expect(@comment.editor).to be_nil

      user2 = DummyUser.create
      user2.can_read = true
      user2.can_edit = true
      user2.is_admin = true
      sign_in user2
      put :update, :id => @comment.id, :comment => attributes
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.body).to eq 'Something'
      expect(@comment.editor).to be_nil

      @user.can_read = true
      @user.can_edit = true
      @user.is_admin = true
      sign_in @user
      comment2 = Comment.new
      comment2.thread = @thread
      comment2.creator = @user
      comment2.body = 'Something else'
      comment2.save!
      put :update, :id => @comment.id, :comment => attributes
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.body).to eq 'Something'
      expect(@comment.editor).to be_nil
    end

    it 'must update if authorized' do
      sign_in @user
      attributes = Hash.new
      attributes[:body] = 'Something else'

      @user.can_read = true
      put :update, :id => @comment.id, :comment => attributes
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).editor).to eq @user

      @user.can_read = false
      @user.can_edit = true
      put :update, :id => @comment.id, :comment => attributes
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).editor).to eq @user

      @user.can_edit = false
      @user.is_admin = true
      put :update, :id => @comment.id, :comment => attributes
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).editor).to eq @user
    end

    it "won't delete unless authorized and not deleted" do
      put :delete, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.is_deleted?).to eq false

      sign_in @user

      put :delete, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.is_deleted?).to eq false

      @user.can_read = true
      expect(@comment.delete_by(@user)).to eq true
      put :delete, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).not_to be_empty

      comment2 = Comment.new
      comment2.thread = @thread
      comment2.creator = @user
      comment2.body = 'Something else'
      comment2.save!
      expect(@comment.undelete_by(@user)).to eq true
      put :delete, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.is_deleted?).to eq false
    end

    it 'must delete if authorized and not deleted' do
      sign_in @user

      @user.can_read = true
      put :delete, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).is_deleted?).to eq true
      expect(assigns(:comment).editor).to eq @user

      user2 = DummyUser.create
      sign_in user2
      comment2 = Comment.new
      comment2.thread = @thread
      comment2.creator = @user
      comment2.body = 'Something else'
      comment2.save!

      expect(assigns(:comment).undelete_by(@user)).to eq true
      user2.can_edit = true
      put :delete, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).is_deleted?).to eq true
      expect(assigns(:comment).editor).to eq user2

      expect(assigns(:comment).undelete_by(@user)).to eq true
      user2.can_edit = false
      user2.is_admin = true
      put :delete, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).is_deleted?).to eq true
      expect(assigns(:comment).editor).to eq user2
    end

    it "won't undelete unless authorized and deleted" do
      expect(@comment.delete_by(@user)).to eq true
      put :undelete, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.is_deleted?).to eq true

      sign_in @user

      put :undelete, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.is_deleted?).to eq true

      @user.can_read = true
      expect(@comment.undelete_by(@user)).to eq true
      put :undelete, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).not_to be_empty

      user2 = DummyUser.create
      user2.can_read = true
      user2.can_edit = true
      user2.is_admin = true
      expect(@comment.delete_by(user2)).to eq true
      put :undelete, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.is_deleted?).to eq true

      comment2 = Comment.new
      comment2.thread = @thread
      comment2.creator = @user
      comment2.body = 'Something else'
      comment2.save!
      expect(@comment.undelete_by(@user)).to eq true
      expect(@comment.delete_by(@user)).to eq true
      put :undelete, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.is_deleted?).to eq true
    end

    it 'must undelete if authorized and deleted' do
      sign_in @user

      expect(@comment.delete_by(@user)).to eq true
      @user.can_read = true
      put :undelete, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).is_deleted?).to eq false

      user2 = DummyUser.create
      sign_in user2
      comment2 = Comment.new
      comment2.thread = @thread
      comment2.creator = @user
      comment2.body = 'Something else'
      comment2.save!

      expect(assigns(:comment).delete_by(@user)).to eq true
      user2.can_edit = true
      put :undelete, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).is_deleted?).to eq false

      expect(assigns(:comment).delete_by(@user)).to eq true
      user2.can_edit = false
      user2.is_admin = true
      put :undelete, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).errors).to be_empty
      expect(assigns(:comment).is_deleted?).to eq false
    end

    it "won't upvote unless authorized" do
      put :upvote, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.get_upvotes).to be_empty
      expect(@comment.get_downvotes).to be_empty

      sign_in @user
      @user.can_read = true
      put :upvote, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.get_upvotes).to be_empty
      expect(@comment.get_downvotes).to be_empty

      user2 = DummyUser.create
      sign_in user2
      put :upvote, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.get_upvotes).to be_empty
      expect(@comment.get_downvotes).to be_empty
    end

    it 'must upvote if authorized' do
      user2 = DummyUser.create
      user2.can_read = true
      sign_in user2

      put :upvote, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).get_upvotes.count).to eq 1
      expect(assigns(:comment).get_downvotes).to be_empty

      put :upvote, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).get_upvotes.count).to eq 1
      expect(assigns(:comment).get_downvotes).to be_empty

      expect(@comment.downvote_from(user2)).to eq true

      put :upvote, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).get_upvotes.count).to eq 1
      expect(assigns(:comment).get_downvotes).to be_empty
    end

    it "won't downvote unless authorized" do
      put :downvote, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.get_upvotes).to be_empty
      expect(@comment.get_downvotes).to be_empty

      sign_in @user
      @user.can_read = true
      put :downvote, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.get_upvotes).to be_empty
      expect(@comment.get_downvotes).to be_empty

      user2 = DummyUser.create
      sign_in user2
      put :downvote, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.get_upvotes).to be_empty
      expect(@comment.get_downvotes).to be_empty
    end

    it 'must downvote if authorized' do
      user2 = DummyUser.create
      user2.can_read = true
      sign_in user2

      put :downvote, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(@comment.get_upvotes).to be_empty
      expect(@comment.get_downvotes.count).to eq 1

      put :downvote, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(@comment.get_upvotes).to be_empty
      expect(@comment.get_downvotes.count).to eq 1

      expect(@comment.upvote_from(user2)).to eq true

      put :downvote, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(@comment.get_upvotes).to be_empty
      expect(@comment.get_downvotes.count).to eq 1
    end

    it "won't unvote unless authorized" do
      expect(@comment.upvote_from(@user)).to eq true

      put :unvote, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.get_upvotes.count).to eq 1
      expect(@comment.get_downvotes).to be_empty

      sign_in @user
      @user.can_read = true
      put :unvote, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.get_upvotes.count).to eq 1
      expect(@comment.get_downvotes).to be_empty

      user2 = DummyUser.create
      sign_in user2
      put :unvote, :id => @comment.id
      expect(response).to have_http_status(:forbidden)
      @comment.reload
      expect(@comment.get_upvotes.count).to eq 1
      expect(@comment.get_downvotes).to be_empty
    end

    it 'must unvote if authorized' do
      user2 = DummyUser.create
      user2.can_read = true
      sign_in user2

      expect(@comment.upvote_from(user2)).to eq true
      put :unvote, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).get_upvotes).to be_empty
      expect(assigns(:comment).get_downvotes).to be_empty

      put :unvote, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).get_upvotes).to be_empty
      expect(assigns(:comment).get_downvotes).to be_empty

      expect(@comment.downvote_from(user2)).to eq true
      put :unvote, :id => @comment.id
      expect(response).to redirect_to @thread
      expect(assigns(:comment).get_upvotes).to be_empty
      expect(assigns(:comment).get_downvotes).to be_empty
    end

    it "won't send mail if recipients empty" do
      user2 = DummyUser.create
      user2.can_read = true

      @user.can_read = true
      sign_in @user

      attributes = { :body => 'Something else' }
      expect {
        post :create, :thread_id => @thread.id, :comment => attributes
      }.not_to change{ ActionMailer::Base.deliveries.count }
      expect(assigns(:comment).errors).to be_empty
    end

    it 'must send mail if recipients not empty' do
      user2 = DummyUser.create
      user2.can_read = true
      @thread.subscribe(user2)

      @user.can_read = true
      sign_in @user

      attributes = { :body => 'Something else' }
      expect {
        post :create, :thread_id => @thread.id, :comment => attributes
      }.to change{ ActionMailer::Base.deliveries.count }.by(1)
      expect(assigns(:comment).errors).to be_empty
    end
  end
end

