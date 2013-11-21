require 'csv'

module Transition
  module Import
    class WhitehallDocumentURLs
      def initialize(user)
        @user = user
      end

      def from_csv(urls_io)
        as_a_user(@user) do
          # Rows are like:
          # Old Url,New Url,Status,Slug,Admin Url,State
          CSV.new(urls_io, headers: true).each do |row|
            next if row[0].blank?
            next unless row[5] == 'published'

            begin
              old_uri = URI.parse(row[0])
            rescue URI::InvalidURIError => e
              Rails.logger.warn("Skipping mapping for unparseable Old Url in Whitehall URL CSV: #{row[0]}")
              next
            end

            host = Host.find_by_hostname(old_uri.host)

            if host
              canonical_path = host.site.canonical_path_from_url(row[0])
              existing_mapping = host.site.mappings.where(path_hash: path_hash(canonical_path)).first
              if existing_mapping
                existing_mapping.update_attributes(new_url: row[1], http_status: '301')
              else
                host.site.mappings.create(path: canonical_path, new_url: row[1], http_status: '301')
              end
            else
              Rails.logger.warn("Skipping mapping for unknown host in Whitehall URL CSV: '#{old_uri.host}'")
            end
          end
        end
      end

      def path_hash(canonical_path)
        Digest::SHA1.hexdigest(canonical_path)
      end

      def as_a_user(user)
        original_whodunnit = ::PaperTrail.whodunnit
        ::PaperTrail.whodunnit = user
        begin
          yield
        ensure
          ::PaperTrail.whodunnit = original_whodunnit
        end
      end
    end
  end
end
