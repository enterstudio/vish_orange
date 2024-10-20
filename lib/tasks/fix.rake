# encoding: utf-8

namespace :fix do

  #Usage
  #Development:   bundle exec rake fix:pictures
  #In production: bundle exec rake fix:pictures RAILS_ENV=production
  task :pictures => :environment do

    printTitle("Fixing pictures")

    #Get all excursions
    excursions = Excursion.all
    excursions.each do |excursion|
      begin
        jsonChange = false
        eJson = JSON(excursion.json)
        eJson["slides"].each do |slide|
          sElements = slide["elements"]
          if sElements != nil
            sElements.each do |el|
              if el["type"]=="image" and el["body"].class == String
                imgPath = el["body"]
                if _isWrongImagePath(imgPath)
                  # puts imgPath
                  #Fix it
                  el["body"] = Vish::Application.config.full_domain + imgPath
                  # puts "Fix image, new URL:"
                  # puts el["body"]
                  jsonChange = true
                end
              end
            end
          end
        end
        if jsonChange
          puts "Excursion ID"
          puts excursion.id
          #excursion.update_column :json, eJson.to_json
        end
      rescue Exception => e
        puts "Exception with excursion id:"
        puts excursion.id.to_s
        puts "Exception message"
        puts e.message
      end
    end

    printTitle("Task Finished")
  end

  def _isWrongImagePath(imagePath)
    return (!imagePath.nil? and imagePath.include?("/pictures/") and !imagePath.include?("vishub") and !imagePath.include?("http://") and !imagePath.include?("https://"))
  end


  #Usage
  #Development:   bundle exec rake fix:resetScormTimestamps
  #In production: bundle exec rake fix:resetScormTimestamps RAILS_ENV=production
  task :resetScormTimestamps => :environment do
    printTitle("Reset SCORM timestamps")

    Excursion.all.map { |ex| 
      ex.update_column :scorm2004_timestamp, nil
      ex.update_column :scorm12_timestamp, nil
    }

    printTitle("Task Finished")
  end


  #Usage
  #Development:   bundle exec rake fix:authors
  #In production: bundle exec rake fix:authors RAILS_ENV=production
  task :authors => :environment do

    printTitle("Fix authors and contributors")

    Excursion.all.select{|e| !e.author.nil?}.map { |ex|
      eJson = JSON(ex.json)

      #Fix author
      eJson["author"] = {name: ex.author.name, vishMetadata:{ id: ex.author.id}}

      #Fix author in quiz_simple_json.
      begin
        eJson["slides"].each do |slide|
          _fixAuthorInSlide(slide,ex)
          unless slide["slides"].nil?
            slide["slides"].each do |subslide|
              _fixAuthorInSlide(subslide,ex)
            end
          end
        end
      rescue
      end

      #Fix contributors
      if ex.contributors
        ex.contributors.uniq!
        ex.contributors.delete(ex.author)
        Excursion.record_timestamps=false
        ex.save!
        Excursion.record_timestamps=true
      end

      if ex.contributors and ex.contributors.length > 0
        eJson["contributors"] = []
      end

      ex.contributors.each do |contributor|
        eJson["contributors"].push({name: contributor.name, vishMetadata:{ id: contributor.id}})
      end

      ex.update_column :json, eJson.to_json
    }

    printTitle("Task Finished")
  end

  def _fixAuthorInSlide(slide,excursion)
    if slide["containsQuiz"]=="true" or slide["containsQuiz"]==true
      slide["elements"].each do |el|
        if el["type"]=="quiz" and !el["quiz_simple_json"].nil?
          el["quiz_simple_json"]["author"] = {name: excursion.author.name, vishMetadata:{ id: excursion.author.id}}
        end
      end
    end
  end


  #Usage
  #Development:   bundle exec rake fix:quizSessionResults
  #In production: bundle exec rake fix:quizSessionResults RAILS_ENV=production
  task :quizSessionResults => :environment do

    printTitle("Fixing Quiz Session Results")

    #Get all excursions
    quizAnswers = QuizAnswer.all
    quizAnswers.each do |qAnswer|
      begin
        answers = JSON(qAnswer.answer)
        newanswers = []

        if !answers.nil?
          answers.each do |answer|
            if !answer["no"].nil?
              answer["choiceId"] = answer["no"]
              answer.delete "no"
            end
            newanswers.push(answer)
          end
        end

        qAnswer.update_column :answer, newanswers.to_json

      rescue Exception => e
        puts "Quiz Answers with id:"
        puts qAnswer.id.to_s
        puts "Exception message"
        puts e.message
      end
    end

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:fillExcursionsLanguage
  #In production: bundle exec rake fix:fillExcursionsLanguage RAILS_ENV=production
  task :fillExcursionsLanguage => :environment do

    printTitle("Filling Excursions language")

    validLanguageCodes = ["de","en","es","fr","it","pt","ru"]
    #"ot" is for "other"

    Excursion.all.map { |ex|
      eJson = JSON(ex.json)

      lan = eJson["language"]
      emptyLan = (lan.nil? or !lan.is_a? String or lan=="independent")

      if emptyLan and !Vish::Application.config.APP_CONFIG["languageDetectionAPIKEY"].nil?
        #Try to infer language
        #Use https://github.com/detectlanguage/detect_language gem

        stringToTestLanguage = ""
        if ex.title.is_a? String and !ex.title.blank?
          stringToTestLanguage = stringToTestLanguage + ex.title + " "
        end
        if ex.description.is_a? String and !ex.description.blank?
          stringToTestLanguage = stringToTestLanguage + ex.description + " "
        end

        if stringToTestLanguage.is_a? String and !stringToTestLanguage.blank?
          detectionResult = (DetectLanguage.detect(stringToTestLanguage) rescue [])
          detectionResult.each do |result|
            if result["isReliable"] == true
              detectedLanguageCode = result["language"]
              if validLanguageCodes.include? detectedLanguageCode
                lan = detectedLanguageCode
              else
                lan = "ot"
              end
              emptyLan = false
              break
            end
          end
        end
      end

      if !emptyLan
        ao = ex.activity_object
        if ao.language != lan
          ao.update_column :language, lan
        end

        if eJson["language"] != lan
          eJson["language"] = lan
          ex.update_column :json, eJson.to_json
        end
      end

    }

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:AOsLanguage
  #In production: bundle exec rake fix:AOsLanguage RAILS_ENV=production
  task :AOsLanguage => :environment do
    User.all.select{|u| u.language.blank?}.each do |user|
      user.update_column :language, "en"
      user.activity_object.update_column :language, "en"
    end

    ActivityObject.all.select{|ao| ao.language.blank?}.each do |ao|
      if ao.object_type=="Actor"
        ao.update_column :language, "en"
      elsif ["Document", "Link", "Excursion", "Embed", "Scormfile", "Webapp"].include? ao.object_type
        ao.update_column :language, "independent"
      end
    end

    User.all.select{|u| !u.language.blank? and u.language!=u.activity_object.language}.each do |user|
      user.activity_object.update_column :language, user.language
    end
  end

  

  #Usage
  #Development:   bundle exec rake fix:recalculateScores
  #In production: bundle exec rake fix:recalculateScores RAILS_ENV=production
  task :recalculateScores => :environment do
    printTitle("Recalculating activity object scores")
    ActivityObject.all.each do |ao|
      ao.calculate_qscore
    end
    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:fillIndexedLengths
  #In production: bundle exec rake fix:fillIndexedLengths RAILS_ENV=production
  task :fillIndexedLengths => :environment do
    printTitle("Filling indexed lengths")
    ActivityObject.all.each do |ao|
      if ao.title.is_a? String and ao.title.scan(/\w+/).size>0
        ao.update_column :title_length, ao.title.scan(/\w+/).size
      end
      if ao.description.is_a? String and ao.description.scan(/\w+/).size>0
        ao.update_column :desc_length, ao.description.scan(/\w+/).size
      end
      if ao.tag_list.is_a? ActsAsTaggableOn::TagList and ao.tag_list.length>0
        ao.update_column :tags_length, ao.tag_list.length
      end
    end
    printTitle("Task Finished")
  end


  #Usage
  #Development:   bundle exec rake fix:absoluteZipPaths
  #In production: bundle exec rake fix:absoluteZipPaths RAILS_ENV=production
  task :absoluteZipPaths => :environment do
    printTitle("Fixing absolute zip paths")

    (Scormfile.all + Webapp.all).each do |resource|
      unless resource.zippath.nil? or resource.zippath.index("/documents/").nil? or resource.zippath.index("/documents/")==0
        newZippath = resource.zippath[resource.zippath.index("/documents/")..-1]
        resource.update_column :zippath, newZippath
      end

      #Fix also loPaths when APP_CONFIG["code_path"] is not defined
      if Vish::Application.config.APP_CONFIG["code_path"].nil?
        unless resource.class != Scormfile or resource.lopath.nil? or resource.lopath.index("/public/scorm/packages").nil? or resource.lopath.index("/public/scorm/packages")==0
          #Fix Scormfiles
          newLopath = resource.lopath[resource.lopath.index("/public/scorm/packages")..-1]
          resource.update_column :lopath, newLopath
        end

        unless resource.class != Webapp or resource.lopath.nil? or resource.lopath.index("/public/webappscode").nil? or resource.lopath.index("/public/webappscode")==0
          #Fix WebApps
          newLopath = resource.lopath[resource.lopath.index("/public/webappscode")..-1]
          resource.update_column :lopath, newLopath
        end
      end

    end

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:ViSHCompetition2013
  #In production: bundle exec rake fix:ViSHCompetition2013 RAILS_ENV=production
  task :ViSHCompetition2013 => :environment do
    printTitle("Fixing ViSH Competitions 2013")

    competitionsIds = [616, 560, 488, 485, 483, 477, 476, 634, 515, 543, 484, 487, 486, 516, 517, 601, 512, 536, 527, 479, 617, 556, 480, 631, 44, 64, 620, 511, 287, 614, 603, 590, 522, 592, 659, 656, 74, 531, 496, 613, 682, 503, 448, 606, 450, 632, 508, 510, 675, 667, 564, 474, 562, 668, 645, 605, 530, 97, 669, 397, 465, 650, 458, 520, 430, 646, 648, 435, 390, 461, 431, 624, 630, 526, 539, 162, 657, 432, 454, 540, 437, 460, 433, 429, 593, 492, 434, 463, 647, 469, 414, 436, 653, 563, 548, 439, 654, 490, 440, 629, 441, 447, 535, 636, 602, 655, 421, 644, 591, 600, 491, 473, 468, 416, 660, 415, 413, 412, 678, 580, 674, 579, 686, 676, 688, 637, 482, 842, 481]

    Excursion.record_timestamps=false
    ActivityObject.record_timestamps=false

    competitionsIds.each do |id|
      e = Excursion.find(id) rescue nil
      unless e.nil?
        e.tag_list.push("ViSHCompetition2013")
        e.tag_list.uniq!
        e.save!
      end
    end

    Excursion.record_timestamps=true
    ActivityObject.record_timestamps=true

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:actorRelations
  #In production: bundle exec rake fix:actorRelations RAILS_ENV=production
  task :actorRelations => :environment do
    printTitle("Fixing Actor relations")

    Actor.record_timestamps=false
    User.record_timestamps=false
    ActivityObject.record_timestamps=false

    Actor.all.each do |actor|
      if actor.admin?
        actor.activity_object.scope = 1
        actor.activity_object.relation_ids = [Relation::Private.instance.id]
      else
        actor.activity_object.scope = 0
        actor.activity_object.relation_ids = [Relation::Public.instance.id]
      end
      actor.save!
    end

    Actor.record_timestamps=true
    User.record_timestamps=true
    ActivityObject.record_timestamps=true

    printTitle("Task Finished")
  end


  #Usage
  #Development:   bundle exec rake fix:scopes
  #In production: bundle exec rake fix:scopes RAILS_ENV=production
  task :scopes => :environment do
    printTitle("Fixing scopes")

    Rake::Task["fix:actorRelations"].invoke

    # publicRelationId = Relation::Public.instance.id
    privateRelationId = Relation::Private.instance.id

    ActivityObject.all.each do |ao|
      unless ao.object.nil?
        if (!ao.relation_ids.nil? and (ao.relation_ids.include? privateRelationId) and ao.scope==0)
          #This is a private ao
          ao.update_column :scope, 1
        end
      end
    end

    printTitle("Task Finished")
  end


  #Usage
  #Development:   bundle exec rake fix:scopeForVEResources
  #In production: bundle exec rake fix:scopeForVEResources RAILS_ENV=production
  task :scopeForVEResources => :environment do
    printTitle("Fixing scope for resources uploaded from VE")

    ActivityObject.record_timestamps=false

    ActivityObject.where("scope=0 and object_type in (?)", ["Document", "Webapp", "Scormfile","Link","Embed"]).select{ |ao|
        !ao.object.nil? and !ao.owner.nil? and !ao.description.nil? and ao.description.start_with? "Uploaded by" and (ao.description.end_with? "via Vish Editor" or ao.description.end_with? "via ViSH Editor")
    }.each do |ao|
      ao.object.class.record_timestamps=false
      ao.scope = 1
      ao.save!
      ao.object.class.record_timestamps=true
    end

    ActivityObject.record_timestamps=true

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:removeInvalidSpamReports
  #In production: bundle exec rake fix:removeInvalidSpamReports RAILS_ENV=production
  task :removeInvalidSpamReports => :environment do
    printTitle("Removing invalid/corrupted spam reports")

    SpamReport.all.each do |report|
      if report.activity_object_id.nil? or report.activity_object.nil? or report.activity_object.object_type.nil? or SpamReport.disabledActivityObjectTypes.include? report.activity_object.object_type or report.report_value.nil? or ![0,1].include? report.report_value
        report.destroy
      else
        #Fix other fields
        if report.reporter_actor_id == 0
          report.update_column :reporter_actor_id, nil
        end
      end
    end

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:downloadExternalAvatars
  #In production: bundle exec rake fix:downloadExternalAvatars RAILS_ENV=production
  task :downloadExternalAvatars => :environment do
    printTitle("Downloading external avatars")

    system("rm -rf tmp/externalAvatars")
    system("mkdir -p tmp/externalAvatars")

    #Set a specific owner
    owner = User.find_by_email("virtual.science.hub+1@gmail.com")

    Excursion.record_timestamps=false
    ActivityObject.record_timestamps=false

    excursionsToFix = Excursion.all

    excursionsToFix.each_with_index do |e,index|
      oldAvatarURL = e.thumbnail_url
      next if oldAvatarURL.blank?

      #Check if the avatar is from vish or is external
      if oldAvatarURL.include?(Vish::Application.config.full_domain)
        #is from vish
        if oldAvatarURL.include?(Vish::Application.config.full_domain + "/pictures/")
          newAvatarURL = oldAvatarURL.split("?")[0] + "?style=500"
        else
          newAvatarURL = oldAvatarURL
        end
      else
        #download the avatar
        owner = owner || e.owner
        newAvatarURL = downloadAvatar(oldAvatarURL,owner,index)
      end
      
      eJson = JSON(e.json)
      eJson["avatar"] = newAvatarURL
      e.update_column :json, eJson.to_json
      e.update_column :thumbnail_url, newAvatarURL
    end

    Excursion.record_timestamps=true
    ActivityObject.record_timestamps=true

    system("rm -rf tmp/externalAvatars")

    printTitle("Task Finished")
  end

  def downloadAvatar(pictureURL,owner,index)
    begin
      pictureURI = URI.parse(pictureURL)
      fileName = index.to_s + "_" + File.basename(pictureURI.path)
      filePath = "tmp/externalAvatars/" + fileName
      pictureURL = URI.encode(pictureURL)
      command = "wget " + pictureURL + " --output-document='" + filePath + "'"
      system(command)
    rescue => e
      filePath = nil
      fileName = index.to_s + "_default"
    end
    
    if filePath.nil? or !File.exist?(filePath) or File.zero?(filePath)
      filePath = Rails.root.to_s + '/app/assets/images/logos/original/ao-default.png'
    end

    pic = Picture.new
    pic.title = fileName
    pic.owner_id = owner.id
    pic.author_id = owner.id
    pic.user_author_id = owner.id
    pic.scope = 1
    pic.file = File.open(filePath, "r")

    begin
      pic.save!
    rescue => e
      #Corrupted (but downloaded) images
      filePath = Rails.root.to_s + '/app/assets/images/logos/original/ao-default.png'
      pic.file = File.open(filePath, "r")
      pic.save!
    end

    return pic.getAvatarUrl
  end

  #Usage
  #Development:   bundle exec rake fix:updateDefaultAgeRanges
  #In production: bundle exec rake fix:updateDefaultAgeRanges RAILS_ENV=production
  task :updateDefaultAgeRanges => :environment do

    printTitle("Updating default age ranges")

    aos = ActivityObject.all

    aos.map { |ao|
      if ((ao.age_min === 4) && ((ao.age_max === 20)||(ao.age_max === 30)))
        #Default age range detected
        ao.update_column :age_min, 0
        ao.update_column :age_max, 0

        if ao.object_type=="Excursion"
          #Update json
          excursion = ao.object
          unless excursion.nil?
            eJson = JSON(excursion.json)
            unless eJson["age_range"].blank?
              eJson.delete("age_range")
              excursion.update_column :json, eJson.to_json
            end
          end
        end
      end
    }

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:updateTagsPlainNames
  #In production: bundle exec rake fix:updateTagsPlainNames RAILS_ENV=production
  task :updateTagsPlainNames => :environment do

    printTitle("Updating the plain names of the tags")

    ActsAsTaggableOn::Tag.all.each do |tag|
      tag.update_column :plain_name, ActsAsTaggableOn::Tag.getPlainName(tag.name)
    end

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:updateTagArrayText
  #In production: bundle exec rake fix:updateTagArrayText RAILS_ENV=production
  task :updateTagArrayText => :environment do
    printTitle("Updating the tag_array_text field of the activity objects")
    ActivityObject.all.each do |ao|
      ao.update_column :tag_array_text, ao.save_tag_array_text if ao.tag_list.is_a? ActsAsTaggableOn::TagList
    end
    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:roles
  #In production: bundle exec rake fix:roles RAILS_ENV=production
  task :roles => :environment do

    printTitle("Fixing roles")

    Rake::Task["db:populate:create:roles"].invoke

    Actor.record_timestamps=false
    Actor.all.select{|a| a.roles.empty?}.each do |a|
      a.roles.push(Role.default)
    end
    Actor.record_timestamps=true

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:licenses
  #In production: bundle exec rake fix:licenses RAILS_ENV=production
  task :licenses => :environment do

    printTitle("Fixing licenses")

    Rake::Task["db:populate:create:licenses"].invoke

    defaultPublicLicenseId = License.default.id rescue nil
    defaultPrivateLicenseId = License.find_by_key("private").id rescue nil

    #Assign licenses to AOs
    ActivityObject.all.each do |ao|
      if ao.should_have_license?
        if ao.license_id.nil?
          if ao.private_scope?
            ao.update_column :license_id, defaultPrivateLicenseId
          else
            ao.update_column :license_id, defaultPublicLicenseId
          end
        end

        #License attribution
        if !ao.license.nil? and ao.license.public? and ao.license.requires_attribution? and ao.license_attribution.nil? and ao.original_author.nil? and !ao.owner.nil?
          ao.update_column :license_attribution, ao.default_license_attribution
        end
      end
    end

    #Get all excursions
    Excursion.all.each do |excursion|
        eJson = JSON(excursion.json)
        jsonChanged = false

        unless excursion.draft
          unless eJson["vishMetadata"].is_a? Hash
            eJson["vishMetadata"] = {}
          end
          #Mark published excursions as released
          unless eJson["vishMetadata"]["released"]==="true"
            eJson["vishMetadata"]["released"] = "true"
            jsonChanged = true
          end
        else
          #Private license for first drafts
          unless eJson["vishMetadata"].is_a? Hash and eJson["vishMetadata"]["released"]==="true"
            unless defaultPrivateLicenseId.nil?
              excursion.activity_object.update_column :license_id, defaultPrivateLicenseId
            end
          end
        end

        unless eJson["license"].is_a? Hash and eJson["license"]["key"].is_a? String and eJson["license"]["key"]==excursion.license.key
          eJson["license"] = {name: excursion.license.name, key: excursion.license.key}
          jsonChanged = true
        end

        excursion.update_column :json, eJson.to_json if jsonChanged
    end

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:categoriesScope
  #In production: bundle exec rake fix:categoriesScope RAILS_ENV=production
  task :categoriesScope => :environment do
    printTitle("Fixing Categories: changing scope to hidden")

    Category.record_timestamps = false
    ActivityObject.record_timestamps = false

    Category.all.each do |category|
      category.scope = 1
      category.valid?

      unless category.errors.blank?
        if category.errors.full_messages.include?("Title is too long.")
          category.title = category.title[0..49]
        end

        if category.errors.full_messages.include?("There is another category with the same title")
          category.title = category.title[0..44] if category.title.length > 45
          category.title = category.title + "-" + category.id.to_s
        end
      end

      category.save!
    end

    Category.record_timestamps = true
    ActivityObject.record_timestamps = true
  end

  #Usage
  #Development:   bundle exec rake fix:defaultNotificationSettings
  #In production: bundle exec rake fix:defaultNotificationSettings RAILS_ENV=production
  task :defaultNotificationSettings => :environment do
    printTitle("Applying default notification settings to all users")

    Actor.record_timestamps = false
    User.record_timestamps = false
    Profile.record_timestamps = false
    ActivityObject.record_timestamps = false

    User.registered.each do |user|
      user.actor.notification_settings = user.notification_settings.merge(SocialStream.default_notification_settings)
      user.actor.save!
    end

    Actor.record_timestamps = true
    User.record_timestamps = true
    Profile.record_timestamps = true
    ActivityObject.record_timestamps = true
  end

  #Usage
  #Development:   bundle exec rake fix:updateScormPackages
  #In production: bundle exec rake fix:updateScormPackages RAILS_ENV=production
  task :updateScormPackages => :environment do
    printTitle("Updating SCORM Packages")
    Scormfile.record_timestamps=false
    ActivityObject.record_timestamps=false

    Scormfile.all.each do |scormfile|
      begin
        scormfile.updateScormfile
      rescue Exception => e
        puts "Exception in Scormfile with id '" + scormfile.id.to_s + "'. Exception message: " + e.message
      end
    end

    Rake::Task["fix:resetScormTimestamps"].invoke

    Scormfile.record_timestamps=true
    ActivityObject.record_timestamps=true
    printTitle("Task finished")
  end

  #Usage
  #Development:   bundle exec rake fix:originalAuthors
  #In production: bundle exec rake fix:originalAuthors RAILS_ENV=production
  task :originalAuthors => :environment do
    printTitle("Checking original authors")

    ActivityObject.getAllResources.each do |ao|
      if !ao.original_author.nil? and ao.author and ao.author.name==ao.original_author
        ao.update_column :original_author, nil
      end
    end

    printTitle("Task finished")
  end

  #Usage
  #Development:   bundle exec rake fix:createViSH2013Contest
  task :createViSH2013Contest => :environment do
    printTitle("Create the ViSHCompetition 2013 Contest")

    c = Contest.new
    c.name = "vish2013"
    c.template = "vish2013"
    c.show_in_ui = true
    c.settings = ({"enroll" => "false", "submission" => "free", "submission_require_enroll" => "false"}).to_json
    c.save!

    allAos = ActivityObject.where("object_type in (?)", ["Excursion"]).with_tag("ViSHCompetition2013")

    ["Maths","Physics","Chemistry","Biology","Geography","EnvironmentalStudies","Engineering","Humanities","NaturalScience","ComputerScience"].each do |cName|
      cc = ContestCategory.new
      cc.name = cName
      cc.contest_id = c.id
      cc.save!
      cAos = allAos.select{|ao| ao.tags.map{|t| t.plain_name}.include? ActsAsTaggableOn::Tag.getPlainName(cName)}
      cAos.each do |ao|
        cc.addActivityObject(ao)
      end
    end
    
    printTitle("Task finished. ViSH Competition contest created.")
  end

  #Usage
  #Development:   bundle exec rake fix:createEducaInternet2016Contest
  task :createEducaInternet2016Contest => :environment do
    printTitle("Create the EducaInternet 2016 Contest")

    c = Contest.find_by_template("educa2016")
    c.destroy unless c.nil?

    ml = MailList.find_by_name("Educa2016 MailList")
    ml.destroy unless ml.nil?

    #Create MailList
    ml = MailList.new
    ml.name = "Educa2016 MailList"
    ml.settings = ({"require_login" => "false", "require_name" => "false"}).to_json
    ml.save!

    c = Contest.new
    c.name = "educa2016"
    c.template = "educa2016"
    c.show_in_ui = true
    c.settings = ({"enroll" => "false", "submission" => "one_per_user", "submission_require_enroll" => "false"}).to_json
    c.mail_list_id = ml.id
    c.save!

    cc = ContestCategory.new
    cc.name = "General"
    cc.contest_id = c.id
    cc.save!

    printTitle("Task finished. Contest created with id " + c.id.to_s)
  end


  #Usage
  #Development:   bundle exec rake fix:createTestContest
  task :createTestContest => :environment do
    printTitle("Create a test Contest")

    c = Contest.find_by_template("test")
    c.destroy unless c.nil?

    ml = MailList.find_by_name("MailList Contest Test")
    ml.destroy unless ml.nil?

    #Create MailList
    ml = MailList.new
    ml.name = "MailList Contest Test"
    ml.settings = ({"require_login" => "false", "require_name" => "false"}).to_json
    ml.save!

    c = Contest.new
    c.name = "test"
    c.template = "test"
    c.show_in_ui = true
    c.settings = ({"enroll" => "true", "submission" => "one_per_user", "submission_require_enroll" => "false"}).to_json
    c.mail_list_id = ml.id
    c.save!

    cc = ContestCategory.new
    cc.name = "General"
    cc.contest_id = c.id
    cc.save!

    printTitle("Task finished. Test contest created with id " + c.id.to_s)
  end


  ####################
  #Task Utils
  ####################

  def printTitle(title)
    if !title.nil?
      puts "#####################################"
      puts title
      puts "#####################################"
    end
  end

  def printSeparator
    puts ""
    puts "--------------------------------------------------------------"
    puts ""
  end

end
