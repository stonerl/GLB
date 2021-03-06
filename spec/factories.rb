#encoding: utf-8
FactoryGirl.define do
  factory :admin, class: User do
    sequence(:email){|n| "admin_#{n}@example.com"}
    sequence(:name){|n| "admin#{n}"}                                                                     
    password "anything"
    password_confirmation "anything"
    role "admin"
  end
  factory :editor, class: User do
    sequence(:email){|n| "editor_#{n}@example.com"}
    sequence(:name){|n| "editor#{n}"}                                                                     
    password "anything"
    password_confirmation "anything"
    role "editor"
  end
  factory :entry, class: Entry do
    user {create :editor}
    namenskuerzel "ES"
    kennzahl "981:1"
    spaltenzahl "17"
    japanische_umschrift "chi {muchi}"
    kanji "癡 (無癡)"
    chinesisch "chi {wuchi}"
    deutsche_uebersetzung "Torheit, Dummheit {Nicht-Torheit}"
    uebersetzung "Torheit, Dummheit {Nicht-Torheit}"
  end
  factory :comment, class: Comment do
    entry {create :entry}
    user {create :editor}
    comment "Test comment!"
  end
end
