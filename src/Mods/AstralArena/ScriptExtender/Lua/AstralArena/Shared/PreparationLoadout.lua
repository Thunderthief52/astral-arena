-- Each character rolls one item from every slot below. Multiple entries per
-- slot are intentional: the adapter shuffles each pool independently for the
-- party, so split-screen avatars receive varied but equally complete kits.
return {
    { slot = "melee-weapon", displayName = "Longsword +1", templateId = "970c962d-dca1-4b90-8d02-81a4e59e3f08" },
    { slot = "melee-weapon", displayName = "Greatsword +1", templateId = "1a2a58b7-4bd5-44d5-b1fe-8cd7e5b53def" },
    { slot = "melee-weapon", displayName = "Rapier +1", templateId = "5a6cea10-b3f6-4370-8eed-0b69b4ba531a" },
    { slot = "melee-weapon", displayName = "Warhammer +1", templateId = "3e1b3db9-036e-4931-ab92-c3730a1c3d5f" },

    { slot = "caster-weapon", displayName = "Quarterstaff +1", templateId = "2fa18ee4-92df-486f-97d2-dd0a720b6fad" },
    { slot = "caster-weapon", displayName = "Dagger +1", templateId = "1eab180b-5bf9-48ea-aece-7ba20d1deb78" },
    { slot = "caster-weapon", displayName = "Mace +1", templateId = "5a948b12-ca43-4256-9821-0d151036dbd1" },
    { slot = "caster-weapon", displayName = "Club +1", templateId = "b30dca22-22bc-496e-b3b6-dd5744b73869" },

    { slot = "ranged-weapon", displayName = "Longbow +1", templateId = "049173ec-636a-487e-a9ed-bfafeadf6bb7" },
    { slot = "ranged-weapon", displayName = "Shortbow +1", templateId = "a46173b7-afd6-48e0-9c76-817acd027574" },
    { slot = "ranged-weapon", displayName = "Light Crossbow +1", templateId = "509dd5c3-7c72-4335-9b23-19a14a884f2e" },
    { slot = "ranged-weapon", displayName = "Heavy Crossbow +1", templateId = "6af59cba-cc38-4511-9c3b-75caac4b96b5" },
    { slot = "ranged-weapon", displayName = "Hand Crossbow +1", templateId = "d2f396c2-9b1b-4eea-bf21-2f25934f092d" },

    { slot = "light-armour", displayName = "Leather Armour +1", templateId = "90a79e46-e327-41f4-a349-8e4dd70b1892" },
    { slot = "light-armour", displayName = "Studded Leather +1", templateId = "58d7927f-c6eb-4635-85b6-70265c621b3d" },
    { slot = "medium-armour", displayName = "Chain Shirt +1", templateId = "eac652ed-ecf7-4505-bf64-0fec29e7d677" },
    { slot = "medium-armour", displayName = "Half Plate +1", templateId = "c3407c8d-0180-4f5a-9530-e1167e7290b3" },
    { slot = "heavy-armour", displayName = "Chain Mail +1", templateId = "ed7a8055-cf36-42c8-ad77-15a80d19744f" },
    { slot = "heavy-armour", displayName = "Plate Armour +1", templateId = "dd905194-9a67-4c61-b26d-5b4da4725cde" },

    { slot = "helmet", displayName = "Nature's Circlet", templateId = "f4bef44e-57f1-47b5-ab2d-2457ff21c707" },
    { slot = "helmet", displayName = "Warped Headband of Intellect", templateId = "8f4876f1-44d9-4bb8-802e-907c6b0a0dba" },
    { slot = "helmet", displayName = "Cap of Curing", templateId = "e305c00e-a231-41e4-86de-cbb320bafbc8" },
    { slot = "helmet", displayName = "The Lifebringer", templateId = "3ccc28a3-faa5-4664-a46a-39300b2d3803" },

    { slot = "gloves", displayName = "Hellrider's Pride", templateId = "db4d4560-dc72-4d64-b552-5caf442c0927" },
    { slot = "gloves", displayName = "Gloves of Power", templateId = "d22e2679-aff0-4244-9ed2-7aac981b82cf" },
    { slot = "gloves", displayName = "Herbalist's Gloves", templateId = "f3ff7066-f407-41c7-b936-0aff066c08e4" },
    { slot = "gloves", displayName = "Gloves of Fire Resistance", templateId = "9c888908-04d0-4047-bf9d-02d3cecb08d6" },

    { slot = "boots", displayName = "Spiderstep Boots", templateId = "d0666101-d24e-4d2b-bc63-63f67532b38c" },
    { slot = "boots", displayName = "Boots of Aid and Comfort", templateId = "ed82c14d-f047-4c4a-866e-836f33e74e40" },
    { slot = "boots", displayName = "Mystra's Grace", templateId = "baae9783-dcd3-4d6b-bba3-86faf2fe4c8e" },
    { slot = "boots", displayName = "Boots of Healing", templateId = "bc090f4e-ff74-49f6-a3f2-7eb561f57436" },

    { slot = "amulet", displayName = "Amulet of Misty Step", templateId = "338848e7-b2c6-4f97-879b-cb3439b4f959" },
    { slot = "amulet", displayName = "Amulet of Restoration", templateId = "c0b04c1c-afb5-4f02-b832-e12043a2d2c4" },
    { slot = "amulet", displayName = "Selunite Amulet", templateId = "e7bf966a-b611-4c36-89fe-0a3b28393d97" },
    { slot = "amulet", displayName = "Psychic Spark", templateId = "4a9f0479-954f-486c-9534-d7d72c11f919" },

    { slot = "ring", displayName = "Ring of Colour Spray", templateId = "eadad0c4-d4a5-45cb-b4c3-e16a9b3ebe0a" },
    { slot = "ring", displayName = "Ring of Searing Smite", templateId = "f09b6c2f-e5f3-43df-82c7-9ed5862a7421" },
    { slot = "ring", displayName = "Crusher's Ring", templateId = "41eed7f8-308a-4ab8-9f47-8ef619d6da57" },
    { slot = "ring", displayName = "The Whispering Promise", templateId = "4aef9bb0-38a8-428e-8b87-6e462d612dd6" },
}
