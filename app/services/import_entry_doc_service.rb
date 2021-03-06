class ImportEntryDocService
  def self.import_entry file
    log = open("error_log", "a")
    begin
      html = Nokogiri::HTML(open(file))
      entry = EntryDoc.new
      entry.update_attribute(:page_reference, file[/\/.+\.html/].gsub("/", "").gsub("html", "doc"))

      entry.update_attribute(:kennzahl, self.page_reference_to_kennzahl(entry.page_reference))

      fields = [ :namenskuerzel,
                 :kennzahl,
                 :spaltenzahl,
                 :lemma_titel, #Non existent
                 :japanische_umschrift,
                 :kanji,
                 :pali,
                 :sanskrit,
                 :chinesisch,
                 :tibetisch,
                 :koreanisch,
                 :weitere_sprachen,
                 :alternative_japanische_lesungen,
                 :schreibvarianten,
                 :deutsche_uebersetzung,
                 :weitere_angaben, #Non existent
                 :lemma_art,
                 :jahreszahlen
      ]
      lemma_art = { "1" => "Person",
                    "2" => "Tempel",
                    "3" => "Werk",
                    "4" => "Fachtermini",
                    "5" => "Geographische Bezeichnung",
                    "6" => "Ereignis"
      }

      #Import first table
      html.css("table")[0].css("tr").each_with_index do |tr, i|
        if tr.css("td")[1] && !(i == 3 || i == 15) && tr.css("td")[0].text.strip != ""
          if i == 16 #Art des Lemmas
            entry.update_attribute(fields[i], lemma_art[tr.css("td")[1].text.strip])
          else
            entry.update_attribute(fields[i], tr.css("td")[1].text.strip.gsub(/\s+/, " "))
          end
        end
      end

      entry.update_attribute(:kennzahl, self.fix_kennzahl(entry.kennzahl))

      #Import Uebersetzung
      translation = html.xpath("//p[preceding-sibling::table[2]] | //ol[preceding-sibling::table[2]]")
      tagged_words = fetch_meta_tags translation
      text = self.tag_entry_text(translation.to_html, tagged_words)
      entry.update_attribute(:uebersetzung, text)

      puts entry.uebersetzung
      #Import 2. table Literatur, Quellen
      fields = [:quellen, :literatur]
      html.css("table")[2].css("tr").each_with_index do |tr, i|
        if tr.css("td")[1] && !tr.css("td")[1].text.strip.blank?
          tagged_words = self.fetch_meta_tags(tr.css("td")[1])
          entry.update_attribute(fields[i], self.tag_entry_text(tr.css("td")[1].to_html, tagged_words))
        end
      end


      #Import 3. table Eigene Ergaenzung
      if html.css("table")[3]
        html.css("table")[3].css("tr").each_with_index do |tr, i|
          if tr.css("td")[1] && !tr.css("td")[1].text.strip.blank?
            tagged_words = self.fetch_meta_tags(tr.css("td")[1])
            entry.update_attribute(:eigene_ergaenzungen, self.tag_entry_text(tr.css("td")[1].to_html, tagged_words))
          end
        end
      end

      #Import 4. table Ergaenzungen Quellen, Literatur
      if html.css("table")[4]
        fields = [:quellen_ergaenzungen, :literatur_ergaenzungen]
        fields.each_with_index do |field, i|
          tr = html.css("table")[4].css("tr")[i]
          if tr.css("td")[1] && !tr.css("td")[1].text.strip.blank?
            tagged_words = self.fetch_meta_tags(tr.css("td")[1])
            entry.update_attribute(fields[i], self.tag_entry_text(tr.css("td")[1].to_html, tagged_words))
          end
        end
      end

      entry.save

    rescue Exception => e
      log.puts e
      log.puts file
    end

    log.close
  end


  private
  def self.page_reference_to_kennzahl page_reference
    kennzahl_parts = page_reference.split(/[._]/)
    kennzahl_parts[0].gsub("m", "").to_i.to_s + ":" + kennzahl_parts[1].to_i.to_s
  end

  def self.fix_kennzahl kennzahl
    #Fix kennzahl
    #i.e. 0030:03 => 30:3
    kennzahl_parts = kennzahl.split(":")
    kennzahl_parts[0].to_i.to_s + ":" + kennzahl_parts[1].to_i.to_s
  end

  # @param text: html source code text
  # There are 2 steps for adding span tags:
  # 1. Replace affected area in html source code with special markups i.e. @werktitel_original@
  # 2. Replace special markups with the correct span tag after parsing: @werktitel_original@ => <span class='werktitel_original'>...
  def self.tag_entry_text text, tagged_words
    tagged_words.each do |css_class, words|
      words.each do |word|
        text = text.gsub(word, "@" + css_class + "@" + Nokogiri::HTML(word).text + "@@")
      end
    end
    markups = {
      "@@" => "</span>",
      "@fachtermini@" => "<span class='fachtermini'>",
      "@sonstiges@" => "<span class='sonstiges'>",
      "@werktitel_original@" => "<span class='werktitel_original'>",
      "@werktitel_fremdspr@" => "<span class='werktitel_fremdspr'>",
      "@eigennamen@" => "<span class='eigennamen'>",
      "@fragliche_stellen@" => "<span class='fragliche_stellen'>"
    }

    parsed_text = Nokogiri::HTML(text).text.strip.gsub(/\s+/, " ")
    markups.each do |markup, span|
      parsed_text = parsed_text.gsub(markup, span)
    end
    parsed_text
  end

  # @param html = html.xpath("//p[preceding-sibling::table[2]]") Übersetzung
  # or html.css("table")[2].css("tr").css("td")[1] Literatur, Quellen
  # return tagged_words 
  # Hash contains {
  #   "werktitel_original": ["<font attr=...>titel</font>", ...]
  #   ...
  # }
  def self.fetch_meta_tags html
    colors = { "#800080" => "werktitel_fremdspr", #lila - fremdspr
               "#0000ff" => "fachtermini", #blau - fachterminus
               "#ff0000" => "eigennamen", #rot - eigennamen
               "#008000" => "sonstiges"#grün - sonstiges
    }


    tagged_words = Hash.new{[]}
    colors.each do |color, css_class|
      tagged_words[css_class] = html.xpath(".//font[@color='" + color + "']").map{|t| t.to_html}
    end

    #Fragliche Stellen
    tagged_words["fragliche_stellen"] = html.css("u").map{|t| t.to_html}
    
    #Werktitel
    tagged_words["werktitel_original"] = html.css("i").map{|t| t.to_html}.reject do |t|
      tagged_words["werktitel_fremdspr"].include?(t) || tagged_words["fachtermini"].include?(t)
    end

    tagged_words
  end
end
