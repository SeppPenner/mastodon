class AddCaseInsensitiveIndexToTags < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    Tag.connection.select_all('SELECT string_agg(id::text, \',\') AS ids FROM tags GROUP BY lower(name) HAVING count(*) > 1').to_hash.each do |row|
      canonical_tag_id  = row['ids'].split(',').first
      redundant_tag_ids = row['ids'].split(',')[1..-1]

      safety_assured do
        execute "UPDATE accounts_tags SET tag_id = #{canonical_tag_id} WHERE tag_id IN (#{redundant_tag_ids.join(', ')})"
        execute "UPDATE statuses_tags SET tag_id = #{canonical_tag_id} WHERE tag_id IN (#{redundant_tag_ids.join(', ')})"
        execute "UPDATE account_tag_stats SET tag_id = #{canonical_tag_id} WHERE tag_id IN (#{redundant_tag_ids.join(', ')})"
        execute "UPDATE featured_tags SET tag_id = #{canonical_tag_id} WHERE tag_id IN (#{redundant_tag_ids.join(', ')})"
      end

      Tag.where(id: redundant_tag_ids).in_batches.delete_all
    end

    safety_assured { execute 'CREATE UNIQUE INDEX CONCURRENTLY index_tags_on_name_lower ON tags (lower(name))' }
    remove_index :tags, name: 'index_tags_on_name'
    remove_index :tags, name: 'hashtag_search_index'
  end

  def down
    add_index :tags, :name, unique: true, algorithm: :concurrently
    safety_assured { execute 'CREATE INDEX CONCURRENTLY hashtag_search_index ON tags (name text_pattern_ops)' }
    remove_index :tags, name: 'index_tags_on_name_lower'
  end
end
