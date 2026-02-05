class AddMultiUseToInvites < ActiveRecord::Migration[8.0]
  def change
    add_column :invites, :multi_use, :boolean, default: false, null: false
    add_column :invites, :max_uses, :integer, default: nil
    add_column :invites, :use_count, :integer, default: 0, null: false
  end
end
