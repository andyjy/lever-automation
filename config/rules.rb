# frozen_string_literal: true
require_relative '../app/base_rules.rb'

#
# Logic for rules we wish to apply
#

TAG_FROM_APPLICATION = AUTO_TAG_PREFIX + 'App: '
TAG_FROM_APP_REVIEW = AUTO_TAG_PREFIX + 'AR: '
TAG_FROM_DEBRIEF = AUTO_TAG_PREFIX + 'Debrief: '

class Rules < BaseRules

  # list of tags for each category, so we can remove when updating with new values
  def all_tags
    {
      source: {
        sourced: 'Sourced',
        referral: 'Referral',
        organic: 'Organic',
        offline: 'Offline',
        offline_organic: 'Offline-or-Organic'
      },
      gender: {
        female: 'Female',
        male: 'Male',
        other: 'Other',
        prefer_not_say: 'Gender: Prefer not to say'
      }
    }  
  end

  def get_links(opp)
    links = []
    responses = opp['_app_responses']
    responses.each {|qu|
      if qu[:_text].include?('url') || qu[:_text].include?('links')
        next if qu[:_text].include?('who is')
        new_links = qu['value'].scan(/[^\s]+\.[^\s]+/)
        next unless new_links.any?
        links += new_links
        log.log("Added links from app field '#{qu[:_text]}': " + new_links.join(', '))
      end
    }
    links.uniq
  end
  
  def summarise_one_feedback(f)
    result = {}
    
    # feedback type
    type = f['text'].downcase.gsub(/[^a-z ]/, '')
    result['type'] =
      if type.include?('coffee')
        'coffee'
      elsif type.include?('app review')
        'app_review'
      elsif type.include?('interview debrief')
        'debrief'
      else
        'unknown'
      end
      
    result['rating'] = (f['fields'].select{|f| f['_text'] == 'rating'}.first || {})['_value']
    result
  end

  def summarise_all_feedback(summaries)
    result = {}
    
    result
  end

  def update_tags
    # application
    if Util.has_application(@opp) && Util.is_cohort_app(@opp)
      # automatically add tag for the opportunity source based on self-reported data in the application
      apply_single_tag(TAG_FROM_APPLICATION, source_from_app(@opp), tags(:source))
      apply_single_tag(TAG_FROM_APPLICATION, gender_from_app(@opp), tags(:gender))
    end
  end

  def source_from_app(opp)
    responses = opp['_app_responses']
    return {msg: "Couldn't find custom question responses."} if responses.nil?

    tags = tags(:source)

    # 1: "who referred you"
    responses.each {|qu|
      if qu[:_text].include?('who referred you')
        return {tag: tags[:referral], field: qu['text'], value: "<not empty>"} if qu['value'] > ''
      end
    }

    responses.each {|qu|
      if qu[:_text].include?('who told you about ef')
        map = [
          ['been on the ef programme', tags[:referral]],
          ['worked at ef', tags[:referral]],
          ['professional network', tags[:organicl]],
          ['friends or family', tags[:organic]]
        ]
        source = nil
        map.each { |m|
          return {tag: m[1], field: qu['text'], value: qu['value']} if qu[:_value].include? m[0]
        }
      end
    }

    responses.each {|qu|
      if qu[:_text].include?('how did you hear about ef')
        map = [
          ['directly contacted by ef', tags[:sourced]],
          ['cohort member', tags[:referral]],
          ['someone else', tags[:organic]], # if not already covered above by latter questions
          ['came across ef', tags[:offline_organic]],
          ['event', tags[:offline]]
        ]
        source = nil
        map.each { |m|
          return {tag: m[1], field: qu['text'], value: qu['value']} if qu[:_value].include? m[0]
        }
      end
    }
    
    # otherwise, unable to determine source from application
    nil
  end

  def gender_from_app(opp)
    responses = opp['_app_responses']
    return {msg: "Couldn't find custom question responses."} if responses.nil?

    tags = tags(:gender)
    
    responses.each {|qu|
      if qu[:_text] == 'gender'
        tags.each { |t|
          return {tag: t[1], field: qu['text'], value: qu['value']} if qu[:_value] == t[1].downcase.sub('gender: ', '')
        }
      end
    }
    nil
  end
end
