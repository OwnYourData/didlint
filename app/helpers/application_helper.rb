module ApplicationHelper
    # DRI of the SOyA structure used for validation
    def soya_did_dri
        DidLint::Structure.active_dri
    end

    # human-readable source (YAML) of that structure
    def soya_structure_url
        (ENV["SOYA_REPO"] || SOYA_REPO) + "/" + soya_did_dri + "/yaml"
    end

    # status of the DIF-recommended methods and did:oyd, nil if not available
    def method_status
        @method_status = DidLint::MethodStatus.current unless defined?(@method_status)
        @method_status
    end

    METHOD_STATUS_BADGES = {
        "conforms" => ["ok", "conforms"],
        "violations" => ["bad", "violations"],
        "not_resolvable" => ["wip", "not resolvable"],
        "error" => ["wip", "no result"]
    }.freeze

    # [CSS class, label] of the badge for one checked DID
    def method_status_badge(entry)
        METHOD_STATUS_BADGES.fetch(entry[:status])
    end

    # the line below a checked DID: first finding, resolver message or notes,
    # and the date of the result if the latest check got none
    def method_status_detail(entry, generated)
        text = entry[:detail]
        if text.nil? && entry[:status] == "conforms" && entry[:notes] > 0
            text = entry[:notes] == 1 ? "with 1 note" : "with #{entry[:notes]} notes"
        end
        if entry[:checked] && entry[:checked] < generated
            text = [text, "result from #{entry[:checked].utc.strftime("%-d %B %Y")}"].compact.join(" · ")
        end
        text
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
