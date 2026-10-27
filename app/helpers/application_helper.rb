module ApplicationHelper
    # DRI of the SOyA structure used for validation
    def soya_did_dri
        DidLint::Structure.active_dri
    end

    # human-readable source (YAML) of that structure
    def soya_structure_url
        (ENV["SOYA_REPO"] || SOYA_REPO) + "/" + soya_did_dri + "/yaml"
    end

    # Returns the full title on a per-page basis.
    def full_title(page_title = '')
        base_title = "OwnYourData"
        if page_title.empty?
            base_title
        else
            page_title + " · " + base_title
        end
    end
end
