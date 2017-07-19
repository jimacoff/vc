class RemoveTrelloFromCompany < ActiveRecord::Migration[5.1]
  def up
    Company.find_each do |company|
      Card.create! company: company, trello_id: company[:trello_id], list_id: company[:list_id]
    end
    remove_column :companies, :trello_id, :string
    remove_reference :companies, :list, foreign_key: true
  end

  def down
    add_column :companies, :trello_id, :string
    add_reference :companies, :list, foreign_key: true
  end
end
