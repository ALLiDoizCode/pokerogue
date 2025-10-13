--[[
  Character Dialogue Engine Process

  Purpose: Character dialogue generation for Mystery Encounters
  Epic: Epic 19 - Mystery Encounter System
  Story: 19.3 - Character Dialogue Generation Migration

  Capabilities:
  - Retrieve personality-appropriate dialogue for trainer types
  - Deterministic random dialogue variant selection
  - Speaker name mapping for UI rendering
  - Context-aware dialogue token injection
  - Personality validation and enumeration

  ADP v1.0 Compliance: Self-documenting process with Info handler
  AO Compliance: Monolithic design, direct error handling, deterministic execution
]]

-- JSON library (permitted in AO)
local json = require("json")

--[[
  TRAINER TYPE ENUMERATION
  Maps to TypeScript TrainerType enum values
  Source: src/enums/trainer-type.ts
]]
local TRAINER_TYPES = {
  UNKNOWN = 0,
  ACE_TRAINER = 1,
  ARTIST = 2,
  BACKERS = 3,
  BACKPACKER = 4,
  BAKER = 5,
  BEAUTY = 6,
  BIKER = 7,
  BLACK_BELT = 8,
  BREEDER = 9,
  CLERK = 10,
  CYCLIST = 11,
  DANCER = 12,
  DEPOT_AGENT = 13,
  DOCTOR = 14,
  FIREBREATHER = 15,
  FISHERMAN = 16,
  GUITARIST = 17,
  HARLEQUIN = 18,
  HIKER = 19,
  HOOLIGANS = 20,
  HOOPSTER = 21,
  INFIELDER = 22,
  JANITOR = 23,
  LINEBACKER = 24,
  MAID = 25,
  MUSICIAN = 26,
  HEX_MANIAC = 27,
  NURSERY_AIDE = 28,
  OFFICER = 29,
  PARASOL_LADY = 30,
  PILOT = 31,
  POKEFAN = 32,
  PRESCHOOLER = 33,
  PSYCHIC = 34,
  RANGER = 35,
  RICH = 36,
  RICH_KID = 37,
  ROUGHNECK = 38,
  SAILOR = 39,
  SCIENTIST = 40,
  SMASHER = 41,
  SNOW_WORKER = 42,
  STRIKER = 43,
  SCHOOL_KID = 44,
  SWIMMER = 45,
  TWINS = 46,
  VETERAN = 47,
  WAITER = 48,
  WORKER = 49,
  YOUNGSTER = 50
}

--[[
  DIALOGUE PHASES
  Maps to dialogue context types
]]
local DIALOGUE_PHASES = {
  ENCOUNTER = "encounter",
  VICTORY = "victory",
  DEFEAT = "defeat"
}

--[[
  TRAINER DIALOGUE DATABASE
  Embedded dialogue pools for all trainer personalities
  Source: src/data/dialogue.ts

  Structure: TRAINER_DIALOGUE[trainerType][phase] = { "dialogue1", "dialogue2", ... }

  Personality Archetypes:
  - Youngster: Enthusiastic, inexperienced, short sentences
  - Ace Trainer: Confident, skilled, challenging tone
  - Hex Maniac: Mysterious, ghostly, otherworldly language
  - Scientist: Analytical, technical, research-focused
  - And 40+ more distinct personalities...
]]
-- Auto-generated dialogue database
-- Source: src/data/dialogue.ts
-- Extracted: 2025-10-06
-- Trainer Types with Dialogue: 233

-- Structure: TRAINER_DIALOGUE[trainerType][variantIndex OR phase] = dialogue_data
-- Variants: Some trainers have multiple gender/personality variants (e.g., Youngster/Lass, Breeder male/female)
-- Direct: Gym Leaders, Elite Four, Champions don't use variant arrays - direct phase keys

local TRAINER_DIALOGUE = {
  [50] = {
    {
      encounter = {
        "dialogue:youngster.encounter.1",
        "dialogue:youngster.encounter.2",
        "dialogue:youngster.encounter.3",
        "dialogue:youngster.encounter.4",
        "dialogue:youngster.encounter.5",
        "dialogue:youngster.encounter.6",
        "dialogue:youngster.encounter.7",
        "dialogue:youngster.encounter.8",
        "dialogue:youngster.encounter.9",
        "dialogue:youngster.encounter.10",
        "dialogue:youngster.encounter.11",
        "dialogue:youngster.encounter.12",
        "dialogue:youngster.encounter.13",
      },
      victory = {
        "dialogue:youngster.victory.1",
        "dialogue:youngster.victory.2",
        "dialogue:youngster.victory.3",
        "dialogue:youngster.victory.4",
        "dialogue:youngster.victory.5",
        "dialogue:youngster.victory.6",
        "dialogue:youngster.victory.7",
        "dialogue:youngster.victory.8",
        "dialogue:youngster.victory.9",
        "dialogue:youngster.victory.10",
        "dialogue:youngster.victory.11",
        "dialogue:youngster.victory.12",
        "dialogue:youngster.victory.13",
      },
    },

    {
      encounter = {
        "dialogue:lass.encounter.1",
        "dialogue:lass.encounter.2",
        "dialogue:lass.encounter.3",
        "dialogue:lass.encounter.4",
        "dialogue:lass.encounter.5",
        "dialogue:lass.encounter.6",
        "dialogue:lass.encounter.7",
        "dialogue:lass.encounter.8",
        "dialogue:lass.encounter.9",
      },
      victory = {
        "dialogue:lass.victory.1",
        "dialogue:lass.victory.2",
        "dialogue:lass.victory.3",
        "dialogue:lass.victory.4",
        "dialogue:lass.victory.5",
        "dialogue:lass.victory.6",
        "dialogue:lass.victory.7",
        "dialogue:lass.victory.8",
        "dialogue:lass.victory.9",
      },
    },
  },
  [9] = {
    {
      encounter = {"dialogue:breeder.encounter.1", "dialogue:breeder.encounter.2", "dialogue:breeder.encounter.3"},
      victory = {"dialogue:breeder.victory.1", "dialogue:breeder.victory.2", "dialogue:breeder.victory.3"},
      defeat = {"dialogue:breeder.defeat.1", "dialogue:breeder.defeat.2", "dialogue:breeder.defeat.3"},
    },
    {
      encounter = {
        "dialogue:breederFemale.encounter.1",
        "dialogue:breederFemale.encounter.2",
        "dialogue:breederFemale.encounter.3",
      },
      victory = {
        "dialogue:breederFemale.victory.1",
        "dialogue:breederFemale.victory.2",
        "dialogue:breederFemale.victory.3",
      },
      defeat = {"dialogue:breederFemale.defeat.1", "dialogue:breederFemale.defeat.2", "dialogue:breederFemale.defeat.3"},
    },
  },
  [16] = {
    {
      encounter = {"dialogue:fisherman.encounter.1", "dialogue:fisherman.encounter.2", "dialogue:fisherman.encounter.3"},
      victory = {"dialogue:fisherman.victory.1", "dialogue:fisherman.victory.2", "dialogue:fisherman.victory.3"},
    },
    {
      encounter = {
        "dialogue:fishermanFemale.encounter.1",
        "dialogue:fishermanFemale.encounter.2",
        "dialogue:fishermanFemale.encounter.3",
      },
      victory = {
        "dialogue:fishermanFemale.victory.1",
        "dialogue:fishermanFemale.victory.2",
        "dialogue:fishermanFemale.victory.3",
      },
    },
  },
  [45] = {
    {
      encounter = {"dialogue:swimmer.encounter.1", "dialogue:swimmer.encounter.2", "dialogue:swimmer.encounter.3"},
      victory = {"dialogue:swimmer.victory.1", "dialogue:swimmer.victory.2", "dialogue:swimmer.victory.3"},
    },
  },
  [4] = {
    {
      encounter = {
        "dialogue:backpacker.encounter.1",
        "dialogue:backpacker.encounter.2",
        "dialogue:backpacker.encounter.3",
        "dialogue:backpacker.encounter.4",
      },
      victory = {
        "dialogue:backpacker.victory.1",
        "dialogue:backpacker.victory.2",
        "dialogue:backpacker.victory.3",
        "dialogue:backpacker.victory.4",
      },
    },
  },
  [1] = {
    {
      encounter = {
        "dialogue:aceTrainer.encounter.1",
        "dialogue:aceTrainer.encounter.2",
        "dialogue:aceTrainer.encounter.3",
        "dialogue:aceTrainer.encounter.4",
      },
      victory = {
        "dialogue:aceTrainer.victory.1",
        "dialogue:aceTrainer.victory.2",
        "dialogue:aceTrainer.victory.3",
        "dialogue:aceTrainer.victory.4",
      },
      defeat = {
        "dialogue:aceTrainer.defeat.1",
        "dialogue:aceTrainer.defeat.2",
        "dialogue:aceTrainer.defeat.3",
        "dialogue:aceTrainer.defeat.4",
      },
    },
  },
  [30] = {
    {
      encounter = {"dialogue:parasolLady.encounter.1"},
      victory = {"dialogue:parasolLady.victory.1"},
    },
  },
  [46] = {
    {
      encounter = {"dialogue:twins.encounter.1", "dialogue:twins.encounter.2", "dialogue:twins.encounter.3"},
      victory = {"dialogue:twins.victory.1", "dialogue:twins.victory.2", "dialogue:twins.victory.3"},
      defeat = {"dialogue:twins.defeat.1", "dialogue:twins.defeat.2", "dialogue:twins.defeat.3"},
    },
  },
  [11] = {
    {
      encounter = {"dialogue:cyclist.encounter.1", "dialogue:cyclist.encounter.2", "dialogue:cyclist.encounter.3"},
      victory = {"dialogue:cyclist.victory.1", "dialogue:cyclist.victory.2", "dialogue:cyclist.victory.3"},
    },
  },
  [8] = {
    {
      encounter = {"dialogue:blackBelt.encounter.1", "dialogue:blackBelt.encounter.2"},
      victory = {"dialogue:blackBelt.victory.1", "dialogue:blackBelt.victory.2"},
    },

    {
      encounter = {"dialogue:battleGirl.encounter.1"},
      victory = {"dialogue:battleGirl.victory.1"},
    },
  },
  [19] = {
    {
      encounter = {"dialogue:hiker.encounter.1", "dialogue:hiker.encounter.2"},
      victory = {"dialogue:hiker.victory.1", "dialogue:hiker.victory.2"},
    },
  },
  [35] = {
    {
      encounter = {"dialogue:ranger.encounter.1", "dialogue:ranger.encounter.2"},
      victory = {"dialogue:ranger.victory.1", "dialogue:ranger.victory.2"},
      defeat = {"dialogue:ranger.defeat.1", "dialogue:ranger.defeat.2"},
    },
  },
  [40] = {
    {
      encounter = {"dialogue:scientist.encounter.1"},
      victory = {"dialogue:scientist.victory.1"},
    },
  },
  [44] = {
    {
      encounter = {"dialogue:schoolKid.encounter.1", "dialogue:schoolKid.encounter.2"},
      victory = {"dialogue:schoolKid.victory.1", "dialogue:schoolKid.victory.2"},
    },
  },
  [2] = {
    {
      encounter = {"dialogue:artist.encounter.1"},
      victory = {"dialogue:artist.victory.1"},
    },
  },
  [17] = {
    {
      encounter = {"dialogue:guitarist.encounter.1"},
      victory = {"dialogue:guitarist.victory.1"},
    },
  },
  [49] = {
    {
      encounter = {"dialogue:worker.encounter.1"},
      victory = {"dialogue:worker.victory.1"},
    },
    {
      encounter = {"dialogue:workerFemale.encounter.1"},
      victory = {"dialogue:workerFemale.victory.1"},
      defeat = {"dialogue:workerFemale.defeat.1"},
    },
    {
      encounter = {"dialogue:workerDouble.encounter.1"},
      victory = {"dialogue:workerDouble.victory.1"},
    },
  },

  [42] = {
    {
      encounter = {"dialogue:snowWorker.encounter.1"},
      victory = {"dialogue:snowWorker.victory.1"},
    },
    {
      encounter = {"dialogue:snowWorkerDouble.encounter.1"},
      victory = {"dialogue:snowWorkerDouble.victory.1"},
    },
  },
  [27] = {
    {
      encounter = {"dialogue:hexManiac.encounter.1", "dialogue:hexManiac.encounter.2"},
      victory = {"dialogue:hexManiac.victory.1", "dialogue:hexManiac.victory.2"},
      defeat = {"dialogue:hexManiac.defeat.1", "dialogue:hexManiac.defeat.2"},
    },
  },
  [34] = {
    {
      encounter = {"dialogue:psychic.encounter.1"},
      victory = {"dialogue:psychic.victory.1"},
    },
  },
  [29] = {
    {
      encounter = {"dialogue:officer.encounter.1", "dialogue:officer.encounter.2"},
      victory = {"dialogue:officer.victory.1", "dialogue:officer.victory.2"},
    },
  },
  [6] = {
    {
      encounter = {"dialogue:beauty.encounter.1"},
      victory = {"dialogue:beauty.victory.1"},
    },
  },
  [5] = {
    {
      encounter = {"dialogue:baker.encounter.1"},
      victory = {"dialogue:baker.victory.1"},
    },
  },
  [7] = {
    {
      encounter = {"dialogue:biker.encounter.1"},
      victory = {"dialogue:biker.victory.1"},
    },
  },
  [15] = {
    {
      encounter = {
        "dialogue:firebreather.encounter.1",
        "dialogue:firebreather.encounter.2",
        "dialogue:firebreather.encounter.3",
      },
      victory = {
        "dialogue:firebreather.victory.1",
        "dialogue:firebreather.victory.2",
        "dialogue:firebreather.victory.3",
      },
    },
  },
  [39] = {
    {
      encounter = {"dialogue:sailor.encounter.1", "dialogue:sailor.encounter.2", "dialogue:sailor.encounter.3"},
      victory = {"dialogue:sailor.victory.1", "dialogue:sailor.victory.2", "dialogue:sailor.victory.3"},
    },
  },
  [10] = {
    {
      encounter = {"dialogue:clerk.encounter.1", "dialogue:clerk.encounter.2", "dialogue:clerk.encounter.3"},
      victory = {"dialogue:clerk.victory.1", "dialogue:clerk.victory.2", "dialogue:clerk.victory.3"},
    },
    {
      encounter = {
        "dialogue:clerkFemale.encounter.1",
        "dialogue:clerkFemale.encounter.2",
        "dialogue:clerkFemale.encounter.3",
      },
      victory = {"dialogue:clerkFemale.victory.1", "dialogue:clerkFemale.victory.2", "dialogue:clerkFemale.victory.3"},
    },
  },
  [20] = {
    {
      encounter = {"dialogue:hooligans.encounter.1", "dialogue:hooligans.encounter.2"},
      victory = {"dialogue:hooligans.victory.1", "dialogue:hooligans.victory.2"},
    },
  },
  [26] = {
    {
      encounter = {
        "dialogue:musician.encounter.1",
        "dialogue:musician.encounter.2",
        "dialogue:musician.encounter.3",
        "dialogue:musician.encounter.4",
      },
      victory = {"dialogue:musician.victory.1", "dialogue:musician.victory.2", "dialogue:musician.victory.3"},
    },
  },
  [31] = {
    {
      encounter = {
        "dialogue:pilot.encounter.1",
        "dialogue:pilot.encounter.2",
        "dialogue:pilot.encounter.3",
        "dialogue:pilot.encounter.4",
      },
      victory = {
        "dialogue:pilot.victory.1",
        "dialogue:pilot.victory.2",
        "dialogue:pilot.victory.3",
        "dialogue:pilot.victory.4",
      },
    },
  },
  [32] = {
    {
      encounter = {"dialogue:pokefan.encounter.1", "dialogue:pokefan.encounter.2", "dialogue:pokefan.encounter.3"},
      victory = {"dialogue:pokefan.victory.1", "dialogue:pokefan.victory.2", "dialogue:pokefan.victory.3"},
    },
    {
      encounter = {
        "dialogue:pokefanFemale.encounter.1",
        "dialogue:pokefanFemale.encounter.2",
        "dialogue:pokefanFemale.encounter.3",
      },
      victory = {
        "dialogue:pokefanFemale.victory.1",
        "dialogue:pokefanFemale.victory.2",
        "dialogue:pokefanFemale.victory.3",
      },
    },
  },
  [36] = {
    {
      encounter = {"dialogue:rich.encounter.1", "dialogue:rich.encounter.2", "dialogue:rich.encounter.3"},
      victory = {"dialogue:rich.victory.1", "dialogue:rich.victory.2", "dialogue:rich.victory.3"},
    },
    {
      encounter = {
        "dialogue:richFemale.encounter.1",
        "dialogue:richFemale.encounter.2",
        "dialogue:richFemale.encounter.3",
      },
      victory = {"dialogue:richFemale.victory.1", "dialogue:richFemale.victory.2", "dialogue:richFemale.victory.3"},
    },
  },
  [37] = {
    {
      encounter = {"dialogue:richKid.encounter.1", "dialogue:richKid.encounter.2", "dialogue:richKid.encounter.3"},
      victory = {
        "dialogue:richKid.victory.1",
        "dialogue:richKid.victory.2",
        "dialogue:richKid.victory.3",
        "dialogue:richKid.victory.4",
      },
    },
    {
      encounter = {
        "dialogue:richKidFemale.encounter.1",
        "dialogue:richKidFemale.encounter.2",
        "dialogue:richKidFemale.encounter.3",
      },
      victory = {
        "dialogue:richKidFemale.victory.1",
        "dialogue:richKidFemale.victory.2",
        "dialogue:richKidFemale.victory.3",
        "dialogue:richKidFemale.victory.4",
      },
    },
  },
  [51] = {
    {
      encounter = {
        "dialogue:rocketGrunt.encounter.1",
        "dialogue:rocketGrunt.encounter.2",
        "dialogue:rocketGrunt.encounter.3",
        "dialogue:rocketGrunt.encounter.4",
        "dialogue:rocketGrunt.encounter.5",
      },
      victory = {
        "dialogue:rocketGrunt.victory.1",
        "dialogue:rocketGrunt.victory.2",
        "dialogue:rocketGrunt.victory.3",
        "dialogue:rocketGrunt.victory.4",
        "dialogue:rocketGrunt.victory.5",
      },
    },
  },
  [52] = {
    {
      encounter = {"dialogue:archer.encounter.1", "dialogue:archer.encounter.2", "dialogue:archer.encounter.3"},
      victory = {"dialogue:archer.victory.1", "dialogue:archer.victory.2", "dialogue:archer.victory.3"},
    },
  },
  [53] = {
    {
      encounter = {"dialogue:ariana.encounter.1", "dialogue:ariana.encounter.2", "dialogue:ariana.encounter.3"},
      victory = {"dialogue:ariana.victory.1", "dialogue:ariana.victory.2", "dialogue:ariana.victory.3"},
    },
  },
  [54] = {
    {
      encounter = {"dialogue:proton.encounter.1", "dialogue:proton.encounter.2", "dialogue:proton.encounter.3"},
      victory = {"dialogue:proton.victory.1", "dialogue:proton.victory.2", "dialogue:proton.victory.3"},
    },
  },
  [55] = {
    {
      encounter = {"dialogue:petrel.encounter.1", "dialogue:petrel.encounter.2", "dialogue:petrel.encounter.3"},
      victory = {"dialogue:petrel.victory.1", "dialogue:petrel.victory.2", "dialogue:petrel.victory.3"},
    },
  },
  [56] = {
    {
      encounter = {
        "dialogue:magmaGrunt.encounter.1",
        "dialogue:magmaGrunt.encounter.2",
        "dialogue:magmaGrunt.encounter.3",
        "dialogue:magmaGrunt.encounter.4",
        "dialogue:magmaGrunt.encounter.5",
      },
      victory = {
        "dialogue:magmaGrunt.victory.1",
        "dialogue:magmaGrunt.victory.2",
        "dialogue:magmaGrunt.victory.3",
        "dialogue:magmaGrunt.victory.4",
        "dialogue:magmaGrunt.victory.5",
      },
    },
  },
  [57] = {
    {
      encounter = {"dialogue:tabitha.encounter.1", "dialogue:tabitha.encounter.2", "dialogue:tabitha.encounter.3"},
      victory = {"dialogue:tabitha.victory.1", "dialogue:tabitha.victory.2", "dialogue:tabitha.victory.3"},
    },
  },
  [58] = {
    {
      encounter = {"dialogue:courtney.encounter.1", "dialogue:courtney.encounter.2", "dialogue:courtney.encounter.3"},
      victory = {"dialogue:courtney.victory.1", "dialogue:courtney.victory.2", "dialogue:courtney.victory.3"},
    },
  },
  [59] = {
    {
      encounter = {
        "dialogue:aquaGrunt.encounter.1",
        "dialogue:aquaGrunt.encounter.2",
        "dialogue:aquaGrunt.encounter.3",
        "dialogue:aquaGrunt.encounter.4",
        "dialogue:aquaGrunt.encounter.5",
      },
      victory = {
        "dialogue:aquaGrunt.victory.1",
        "dialogue:aquaGrunt.victory.2",
        "dialogue:aquaGrunt.victory.3",
        "dialogue:aquaGrunt.victory.4",
        "dialogue:aquaGrunt.victory.5",
      },
    },
  },
  [60] = {
    {
      encounter = {"dialogue:matt.encounter.1", "dialogue:matt.encounter.2", "dialogue:matt.encounter.3"},
      victory = {"dialogue:matt.victory.1", "dialogue:matt.victory.2", "dialogue:matt.victory.3"},
    },
  },
  [61] = {
    {
      encounter = {"dialogue:shelly.encounter.1", "dialogue:shelly.encounter.2", "dialogue:shelly.encounter.3"},
      victory = {"dialogue:shelly.victory.1", "dialogue:shelly.victory.2", "dialogue:shelly.victory.3"},
    },
  },
  [62] = {
    {
      encounter = {
        "dialogue:galacticGrunt.encounter.1",
        "dialogue:galacticGrunt.encounter.2",
        "dialogue:galacticGrunt.encounter.3",
        "dialogue:galacticGrunt.encounter.4",
        "dialogue:galacticGrunt.encounter.5",
      },
      victory = {
        "dialogue:galacticGrunt.victory.1",
        "dialogue:galacticGrunt.victory.2",
        "dialogue:galacticGrunt.victory.3",
        "dialogue:galacticGrunt.victory.4",
        "dialogue:galacticGrunt.victory.5",
      },
    },
  },
  [63] = {
    {
      encounter = {"dialogue:jupiter.encounter.1", "dialogue:jupiter.encounter.2", "dialogue:jupiter.encounter.3"},
      victory = {"dialogue:jupiter.victory.1", "dialogue:jupiter.victory.2", "dialogue:jupiter.victory.3"},
    },
  },
  [64] = {
    {
      encounter = {"dialogue:mars.encounter.1", "dialogue:mars.encounter.2", "dialogue:mars.encounter.3"},
      victory = {"dialogue:mars.victory.1", "dialogue:mars.victory.2", "dialogue:mars.victory.3"},
    },
  },
  [65] = {
    {
      encounter = {"dialogue:saturn.encounter.1", "dialogue:saturn.encounter.2", "dialogue:saturn.encounter.3"},
      victory = {"dialogue:saturn.victory.1", "dialogue:saturn.victory.2", "dialogue:saturn.victory.3"},
    },
  },
  [66] = {
    {
      encounter = {
        "dialogue:plasmaGrunt.encounter.1",
        "dialogue:plasmaGrunt.encounter.2",
        "dialogue:plasmaGrunt.encounter.3",
        "dialogue:plasmaGrunt.encounter.4",
        "dialogue:plasmaGrunt.encounter.5",
      },
      victory = {
        "dialogue:plasmaGrunt.victory.1",
        "dialogue:plasmaGrunt.victory.2",
        "dialogue:plasmaGrunt.victory.3",
        "dialogue:plasmaGrunt.victory.4",
        "dialogue:plasmaGrunt.victory.5",
      },
    },
  },
  [67] = {
    {
      encounter = {"dialogue:zinzolin.encounter.1", "dialogue:zinzolin.encounter.2", "dialogue:zinzolin.encounter.3"},
      victory = {"dialogue:zinzolin.victory.1", "dialogue:zinzolin.victory.2", "dialogue:zinzolin.victory.3"},
    },
  },
  [68] = {
    {
      encounter = {"dialogue:colress.encounter.1", "dialogue:colress.encounter.2", "dialogue:colress.encounter.3"},
      victory = {"dialogue:colress.victory.1", "dialogue:colress.victory.2", "dialogue:colress.victory.3"},
    },
  },
  [69] = {
    {
      encounter = {
        "dialogue:flareGrunt.encounter.1",
        "dialogue:flareGrunt.encounter.2",
        "dialogue:flareGrunt.encounter.3",
        "dialogue:flareGrunt.encounter.4",
        "dialogue:flareGrunt.encounter.5",
      },
      victory = {
        "dialogue:flareGrunt.victory.1",
        "dialogue:flareGrunt.victory.2",
        "dialogue:flareGrunt.victory.3",
        "dialogue:flareGrunt.victory.4",
        "dialogue:flareGrunt.victory.5",
      },
    },
  },
  [70] = {
    {
      encounter = {"dialogue:bryony.encounter.1", "dialogue:bryony.encounter.2", "dialogue:bryony.encounter.3"},
      victory = {"dialogue:bryony.victory.1", "dialogue:bryony.victory.2", "dialogue:bryony.victory.3"},
    },
  },
  [71] = {
    {
      encounter = {"dialogue:xerosic.encounter.1", "dialogue:xerosic.encounter.2", "dialogue:xerosic.encounter.3"},
      victory = {"dialogue:xerosic.victory.1", "dialogue:xerosic.victory.2", "dialogue:xerosic.victory.3"},
    },
  },
  [72] = {
    {
      encounter = {
        "dialogue:aetherGrunt.encounter.1",
        "dialogue:aetherGrunt.encounter.2",
        "dialogue:aetherGrunt.encounter.3",
        "dialogue:aetherGrunt.encounter.4",
        "dialogue:aetherGrunt.encounter.5",
      },
      victory = {
        "dialogue:aetherGrunt.victory.1",
        "dialogue:aetherGrunt.victory.2",
        "dialogue:aetherGrunt.victory.3",
        "dialogue:aetherGrunt.victory.4",
        "dialogue:aetherGrunt.victory.5",
      },
    },
  },
  [73] = {
    {
      encounter = {"dialogue:faba.encounter.1", "dialogue:faba.encounter.2", "dialogue:faba.encounter.3"},
      victory = {"dialogue:faba.victory.1", "dialogue:faba.victory.2", "dialogue:faba.victory.3"},
    },
  },
  [74] = {
    {
      encounter = {
        "dialogue:skullGrunt.encounter.1",
        "dialogue:skullGrunt.encounter.2",
        "dialogue:skullGrunt.encounter.3",
        "dialogue:skullGrunt.encounter.4",
        "dialogue:skullGrunt.encounter.5",
      },
      victory = {
        "dialogue:skullGrunt.victory.1",
        "dialogue:skullGrunt.victory.2",
        "dialogue:skullGrunt.victory.3",
        "dialogue:skullGrunt.victory.4",
        "dialogue:skullGrunt.victory.5",
      },
    },
  },
  [75] = {
    {
      encounter = {"dialogue:plumeria.encounter.1", "dialogue:plumeria.encounter.2", "dialogue:plumeria.encounter.3"},
      victory = {"dialogue:plumeria.victory.1", "dialogue:plumeria.victory.2", "dialogue:plumeria.victory.3"},
    },
  },
  [76] = {
    {
      encounter = {
        "dialogue:macroGrunt.encounter.1",
        "dialogue:macroGrunt.encounter.2",
        "dialogue:macroGrunt.encounter.3",
        "dialogue:macroGrunt.encounter.4",
        "dialogue:macroGrunt.encounter.5",
      },
      victory = {
        "dialogue:macroGrunt.victory.1",
        "dialogue:macroGrunt.victory.2",
        "dialogue:macroGrunt.victory.3",
        "dialogue:macroGrunt.victory.4",
        "dialogue:macroGrunt.victory.5",
      },
    },
  },
  [77] = {
    {
      encounter = {"dialogue:oleana.encounter.1", "dialogue:oleana.encounter.2", "dialogue:oleana.encounter.3"},
      victory = {"dialogue:oleana.victory.1", "dialogue:oleana.victory.2", "dialogue:oleana.victory.3"},
    },
  },
  [78] = {
    {
      encounter = {
        "dialogue:starGrunt.encounter.1",
        "dialogue:starGrunt.encounter.2",
        "dialogue:starGrunt.encounter.3",
        "dialogue:starGrunt.encounter.4",
        "dialogue:starGrunt.encounter.5",
      },
      victory = {
        "dialogue:starGrunt.victory.1",
        "dialogue:starGrunt.victory.2",
        "dialogue:starGrunt.victory.3",
        "dialogue:starGrunt.victory.4",
        "dialogue:starGrunt.victory.5",
      },
    },
  },
  [79] = {
    {
      encounter = {"dialogue:giacomo.encounter.1", "dialogue:giacomo.encounter.2"},
      victory = {"dialogue:giacomo.victory.1", "dialogue:giacomo.victory.2"},
    },
  },
  [80] = {
    {
      encounter = {"dialogue:mela.encounter.1", "dialogue:mela.encounter.2"},
      victory = {"dialogue:mela.victory.1", "dialogue:mela.victory.2"},
    },
  },
  [81] = {
    {
      encounter = {"dialogue:atticus.encounter.1", "dialogue:atticus.encounter.2"},
      victory = {"dialogue:atticus.victory.1", "dialogue:atticus.victory.2"},
    },
  },
  [82] = {
    {
      encounter = {"dialogue:ortega.encounter.1", "dialogue:ortega.encounter.2"},
      victory = {"dialogue:ortega.victory.1", "dialogue:ortega.victory.2"},
    },
  },
  [83] = {
    {
      encounter = {"dialogue:eri.encounter.1", "dialogue:eri.encounter.2"},
      victory = {"dialogue:eri.victory.1", "dialogue:eri.victory.2"},
    },
  },
  [84] = {
    {
      encounter = {"dialogue:rocketBossGiovanni1.encounter.1"},
      victory = {"dialogue:rocketBossGiovanni1.victory.1"},
      defeat = {"dialogue:rocketBossGiovanni1.defeat.1"},
    },
  },
  [85] = {
    {
      encounter = {"dialogue:rocketBossGiovanni2.encounter.1"},
      victory = {"dialogue:rocketBossGiovanni2.victory.1"},
      defeat = {"dialogue:rocketBossGiovanni2.defeat.1"},
    },
  },
  [86] = {
    {
      encounter = {"dialogue:magmaBossMaxie1.encounter.1"},
      victory = {"dialogue:magmaBossMaxie1.victory.1"},
      defeat = {"dialogue:magmaBossMaxie1.defeat.1"},
    },
  },
  [87] = {
    {
      encounter = {"dialogue:magmaBossMaxie2.encounter.1"},
      victory = {"dialogue:magmaBossMaxie2.victory.1"},
      defeat = {"dialogue:magmaBossMaxie2.defeat.1"},
    },
  },
  [88] = {
    {
      encounter = {"dialogue:aquaBossArchie1.encounter.1"},
      victory = {"dialogue:aquaBossArchie1.victory.1"},
      defeat = {"dialogue:aquaBossArchie1.defeat.1"},
    },
  },
  [89] = {
    {
      encounter = {"dialogue:aquaBossArchie2.encounter.1"},
      victory = {"dialogue:aquaBossArchie2.victory.1"},
      defeat = {"dialogue:aquaBossArchie2.defeat.1"},
    },
  },
  [90] = {
    {
      encounter = {"dialogue:galacticBossCyrus1.encounter.1"},
      victory = {"dialogue:galacticBossCyrus1.victory.1"},
      defeat = {"dialogue:galacticBossCyrus1.defeat.1"},
    },
  },
  [91] = {
    {
      encounter = {"dialogue:galacticBossCyrus2.encounter.1"},
      victory = {"dialogue:galacticBossCyrus2.victory.1"},
      defeat = {"dialogue:galacticBossCyrus2.defeat.1"},
    },
  },
  [92] = {
    {
      encounter = {"dialogue:plasmaBossGhetsis1.encounter.1"},
      victory = {"dialogue:plasmaBossGhetsis1.victory.1"},
      defeat = {"dialogue:plasmaBossGhetsis1.defeat.1"},
    },
  },
  [93] = {
    {
      encounter = {"dialogue:plasmaBossGhetsis2.encounter.1"},
      victory = {"dialogue:plasmaBossGhetsis2.victory.1"},
      defeat = {"dialogue:plasmaBossGhetsis2.defeat.1"},
    },
  },
  [94] = {
    {
      encounter = {"dialogue:flareBossLysandre1.encounter.1"},
      victory = {"dialogue:flareBossLysandre1.victory.1"},
      defeat = {"dialogue:flareBossLysandre1.defeat.1"},
    },
  },
  [95] = {
    {
      encounter = {"dialogue:flareBossLysandre2.encounter.1"},
      victory = {"dialogue:flareBossLysandre2.victory.1"},
      defeat = {"dialogue:flareBossLysandre2.defeat.1"},
    },
  },
  [96] = {
    {
      encounter = {"dialogue:aetherBossLusamine1.encounter.1"},
      victory = {"dialogue:aetherBossLusamine1.victory.1"},
      defeat = {"dialogue:aetherBossLusamine1.defeat.1"},
    },
  },
  [97] = {
    {
      encounter = {"dialogue:aetherBossLusamine2.encounter.1"},
      victory = {"dialogue:aetherBossLusamine2.victory.1"},
      defeat = {"dialogue:aetherBossLusamine2.defeat.1"},
    },
  },
  [98] = {
    {
      encounter = {"dialogue:skullBossGuzma1.encounter.1"},
      victory = {"dialogue:skullBossGuzma1.victory.1"},
      defeat = {"dialogue:skullBossGuzma1.defeat.1"},
    },
  },
  [99] = {
    {
      encounter = {"dialogue:skullBossGuzma2.encounter.1"},
      victory = {"dialogue:skullBossGuzma2.victory.1"},
      defeat = {"dialogue:skullBossGuzma2.defeat.1"},
    },
  },
  [100] = {
    {
      encounter = {"dialogue:macroBossRose1.encounter.1"},
      victory = {"dialogue:macroBossRose1.victory.1"},
      defeat = {"dialogue:macroBossRose1.defeat.1"},
    },
  },
  [101] = {
    {
      encounter = {"dialogue:macroBossRose2.encounter.1"},
      victory = {"dialogue:macroBossRose2.victory.1"},
      defeat = {"dialogue:macroBossRose2.defeat.1"},
    },
  },
  [102] = {
    {
      encounter = {"dialogue:starBossPenny1.encounter.1"},
      victory = {"dialogue:starBossPenny1.victory.1"},
      defeat = {"dialogue:starBossPenny1.defeat.1"},
    },
  },
  [103] = {
    {
      encounter = {"dialogue:starBossPenny2.encounter.1"},
      victory = {"dialogue:starBossPenny2.victory.1"},
      defeat = {"dialogue:starBossPenny2.defeat.1"},
    },
  },
  [104] = {
    {
      encounter = {"dialogue:statTrainerBuck.encounter.1", "dialogue:statTrainerBuck.encounter.2"},
      victory = {"dialogue:statTrainerBuck.victory.1", "dialogue:statTrainerBuck.victory.2"},
      defeat = {"dialogue:statTrainerBuck.defeat.1", "dialogue:statTrainerBuck.defeat.2"},
    },
  },
  [105] = {
    {
      encounter = {"dialogue:statTrainerCheryl.encounter.1", "dialogue:statTrainerCheryl.encounter.2"},
      victory = {"dialogue:statTrainerCheryl.victory.1", "dialogue:statTrainerCheryl.victory.2"},
      defeat = {"dialogue:statTrainerCheryl.defeat.1", "dialogue:statTrainerCheryl.defeat.2"},
    },
  },
  [106] = {
    {
      encounter = {"dialogue:statTrainerMarley.encounter.1", "dialogue:statTrainerMarley.encounter.2"},
      victory = {"dialogue:statTrainerMarley.victory.1", "dialogue:statTrainerMarley.victory.2"},
      defeat = {"dialogue:statTrainerMarley.defeat.1", "dialogue:statTrainerMarley.defeat.2"},
    },
  },
  [107] = {
    {
      encounter = {"dialogue:statTrainerMira.encounter.1", "dialogue:statTrainerMira.encounter.2"},
      victory = {"dialogue:statTrainerMira.victory.1", "dialogue:statTrainerMira.victory.2"},
      defeat = {"dialogue:statTrainerMira.defeat.1", "dialogue:statTrainerMira.defeat.2"},
    },
  },
  [108] = {
    {
      encounter = {"dialogue:statTrainerRiley.encounter.1", "dialogue:statTrainerRiley.encounter.2"},
      victory = {"dialogue:statTrainerRiley.victory.1", "dialogue:statTrainerRiley.victory.2"},
      defeat = {"dialogue:statTrainerRiley.defeat.1", "dialogue:statTrainerRiley.defeat.2"},
    },
  },
  [109] = {
    {
      encounter = {"dialogue:winstratesVictor.encounter.1"},
      victory = {"dialogue:winstratesVictor.victory.1"},
    },
  },
  [110] = {
    {
      encounter = {"dialogue:winstratesVictoria.encounter.1"},
      victory = {"dialogue:winstratesVictoria.victory.1"},
    },
  },
  [111] = {
    {
      encounter = {"dialogue:winstratesVivi.encounter.1"},
      victory = {"dialogue:winstratesVivi.victory.1"},
    },
  },
  [112] = {
    {
      encounter = {"dialogue:winstratesVicky.encounter.1"},
      victory = {"dialogue:winstratesVicky.victory.1"},
    },
  },
  [113] = {
    {
      encounter = {"dialogue:winstratesVito.encounter.1"},
      victory = {"dialogue:winstratesVito.victory.1"},
    },
  },
  [200] = {
    encounter = {"dialogue:brock.encounter.1", "dialogue:brock.encounter.2", "dialogue:brock.encounter.3"},
    victory = {"dialogue:brock.victory.1", "dialogue:brock.victory.2", "dialogue:brock.victory.3"},
    defeat = {"dialogue:brock.defeat.1", "dialogue:brock.defeat.2", "dialogue:brock.defeat.3"},
  },
  [201] = {
    encounter = {"dialogue:misty.encounter.1", "dialogue:misty.encounter.2", "dialogue:misty.encounter.3"},
    victory = {"dialogue:misty.victory.1", "dialogue:misty.victory.2", "dialogue:misty.victory.3"},
    defeat = {"dialogue:misty.defeat.1", "dialogue:misty.defeat.2", "dialogue:misty.defeat.3"},
  },
  [202] = {
    encounter = {"dialogue:ltSurge.encounter.1", "dialogue:ltSurge.encounter.2", "dialogue:ltSurge.encounter.3"},
    victory = {"dialogue:ltSurge.victory.1", "dialogue:ltSurge.victory.2", "dialogue:ltSurge.victory.3"},
    defeat = {"dialogue:ltSurge.defeat.1", "dialogue:ltSurge.defeat.2", "dialogue:ltSurge.defeat.3"},
  },
  [203] = {
    encounter = {
      "dialogue:erika.encounter.1",
      "dialogue:erika.encounter.2",
      "dialogue:erika.encounter.3",
      "dialogue:erika.encounter.4",
    },
    victory = {
      "dialogue:erika.victory.1",
      "dialogue:erika.victory.2",
      "dialogue:erika.victory.3",
      "dialogue:erika.victory.4",
    },
    defeat = {
      "dialogue:erika.defeat.1",
      "dialogue:erika.defeat.2",
      "dialogue:erika.defeat.3",
      "dialogue:erika.defeat.4",
    },
  },
  [204] = {
    encounter = {"dialogue:janine.encounter.1", "dialogue:janine.encounter.2", "dialogue:janine.encounter.3"},
    victory = {"dialogue:janine.victory.1", "dialogue:janine.victory.2", "dialogue:janine.victory.3"},
    defeat = {"dialogue:janine.defeat.1", "dialogue:janine.defeat.2", "dialogue:janine.defeat.3"},
  },
  [205] = {
    encounter = {"dialogue:sabrina.encounter.1", "dialogue:sabrina.encounter.2", "dialogue:sabrina.encounter.3"},
    victory = {"dialogue:sabrina.victory.1", "dialogue:sabrina.victory.2", "dialogue:sabrina.victory.3"},
    defeat = {"dialogue:sabrina.defeat.1", "dialogue:sabrina.defeat.2", "dialogue:sabrina.defeat.3"},
  },
  [206] = {
    encounter = {"dialogue:blaine.encounter.1", "dialogue:blaine.encounter.2", "dialogue:blaine.encounter.3"},
    victory = {"dialogue:blaine.victory.1", "dialogue:blaine.victory.2", "dialogue:blaine.victory.3"},
    defeat = {"dialogue:blaine.defeat.1", "dialogue:blaine.defeat.2", "dialogue:blaine.defeat.3"},
  },
  [207] = {
    encounter = {"dialogue:giovanni.encounter.1", "dialogue:giovanni.encounter.2", "dialogue:giovanni.encounter.3"},
    victory = {"dialogue:giovanni.victory.1", "dialogue:giovanni.victory.2", "dialogue:giovanni.victory.3"},
    defeat = {"dialogue:giovanni.defeat.1", "dialogue:giovanni.defeat.2", "dialogue:giovanni.defeat.3"},
  },
  [216] = {
    encounter = {"dialogue:roxanne.encounter.1", "dialogue:roxanne.encounter.2", "dialogue:roxanne.encounter.3"},
    victory = {"dialogue:roxanne.victory.1", "dialogue:roxanne.victory.2", "dialogue:roxanne.victory.3"},
    defeat = {"dialogue:roxanne.defeat.1", "dialogue:roxanne.defeat.2", "dialogue:roxanne.defeat.3"},
  },
  [217] = {
    encounter = {"dialogue:brawly.encounter.1", "dialogue:brawly.encounter.2", "dialogue:brawly.encounter.3"},
    victory = {"dialogue:brawly.victory.1", "dialogue:brawly.victory.2", "dialogue:brawly.victory.3"},
    defeat = {"dialogue:brawly.defeat.1", "dialogue:brawly.defeat.2", "dialogue:brawly.defeat.3"},
  },
  [218] = {
    encounter = {"dialogue:wattson.encounter.1", "dialogue:wattson.encounter.2", "dialogue:wattson.encounter.3"},
    victory = {"dialogue:wattson.victory.1", "dialogue:wattson.victory.2", "dialogue:wattson.victory.3"},
    defeat = {"dialogue:wattson.defeat.1", "dialogue:wattson.defeat.2", "dialogue:wattson.defeat.3"},
  },
  [219] = {
    encounter = {"dialogue:flannery.encounter.1", "dialogue:flannery.encounter.2", "dialogue:flannery.encounter.3"},
    victory = {"dialogue:flannery.victory.1", "dialogue:flannery.victory.2", "dialogue:flannery.victory.3"},
    defeat = {"dialogue:flannery.defeat.1", "dialogue:flannery.defeat.2", "dialogue:flannery.defeat.3"},
  },
  [220] = {
    encounter = {"dialogue:norman.encounter.1", "dialogue:norman.encounter.2", "dialogue:norman.encounter.3"},
    victory = {"dialogue:norman.victory.1", "dialogue:norman.victory.2", "dialogue:norman.victory.3"},
    defeat = {"dialogue:norman.defeat.1", "dialogue:norman.defeat.2", "dialogue:norman.defeat.3"},
  },
  [221] = {
    encounter = {"dialogue:winona.encounter.1", "dialogue:winona.encounter.2", "dialogue:winona.encounter.3"},
    victory = {"dialogue:winona.victory.1", "dialogue:winona.victory.2", "dialogue:winona.victory.3"},
    defeat = {"dialogue:winona.defeat.1", "dialogue:winona.defeat.2", "dialogue:winona.defeat.3"},
  },
  [222] = {
    encounter = {"dialogue:tate.encounter.1", "dialogue:tate.encounter.2", "dialogue:tate.encounter.3"},
    victory = {"dialogue:tate.victory.1", "dialogue:tate.victory.2", "dialogue:tate.victory.3"},
    defeat = {"dialogue:tate.defeat.1", "dialogue:tate.defeat.2", "dialogue:tate.defeat.3"},
  },
  [223] = {
    encounter = {"dialogue:liza.encounter.1", "dialogue:liza.encounter.2", "dialogue:liza.encounter.3"},
    victory = {"dialogue:liza.victory.1", "dialogue:liza.victory.2", "dialogue:liza.victory.3"},
    defeat = {"dialogue:liza.defeat.1", "dialogue:liza.defeat.2", "dialogue:liza.defeat.3"},
  },
  [224] = {
    encounter = {
      "dialogue:juan.encounter.1",
      "dialogue:juan.encounter.2",
      "dialogue:juan.encounter.3",
      "dialogue:juan.encounter.4",
    },
    victory = {
      "dialogue:juan.victory.1",
      "dialogue:juan.victory.2",
      "dialogue:juan.victory.3",
      "dialogue:juan.victory.4",
    },
    defeat = {"dialogue:juan.defeat.1", "dialogue:juan.defeat.2", "dialogue:juan.defeat.3", "dialogue:juan.defeat.4"},
  },
  [228] = {
    encounter = {
      "dialogue:crasherWake.encounter.1",
      "dialogue:crasherWake.encounter.2",
      "dialogue:crasherWake.encounter.3",
    },
    victory = {"dialogue:crasherWake.victory.1", "dialogue:crasherWake.victory.2", "dialogue:crasherWake.victory.3"},
    defeat = {"dialogue:crasherWake.defeat.1", "dialogue:crasherWake.defeat.2", "dialogue:crasherWake.defeat.3"},
  },
  [208] = {
    encounter = {"dialogue:falkner.encounter.1", "dialogue:falkner.encounter.2", "dialogue:falkner.encounter.3"},
    victory = {"dialogue:falkner.victory.1", "dialogue:falkner.victory.2", "dialogue:falkner.victory.3"},
    defeat = {"dialogue:falkner.defeat.1", "dialogue:falkner.defeat.2", "dialogue:falkner.defeat.3"},
  },
  [255] = {
    encounter = {"dialogue:nessa.encounter.1", "dialogue:nessa.encounter.2", "dialogue:nessa.encounter.3"},
    victory = {"dialogue:nessa.victory.1", "dialogue:nessa.victory.2", "dialogue:nessa.victory.3"},
    defeat = {"dialogue:nessa.defeat.1", "dialogue:nessa.defeat.2", "dialogue:nessa.defeat.3"},
  },
  [262] = {
    encounter = {"dialogue:melony.encounter.1", "dialogue:melony.encounter.2", "dialogue:melony.encounter.3"},
    victory = {"dialogue:melony.victory.1", "dialogue:melony.victory.2", "dialogue:melony.victory.3"},
    defeat = {"dialogue:melony.defeat.1", "dialogue:melony.defeat.2", "dialogue:melony.defeat.3"},
  },
  [245] = {
    encounter = {"dialogue:marlon.encounter.1", "dialogue:marlon.encounter.2", "dialogue:marlon.encounter.3"},
    victory = {"dialogue:marlon.victory.1", "dialogue:marlon.victory.2", "dialogue:marlon.victory.3"},
    defeat = {"dialogue:marlon.defeat.1", "dialogue:marlon.defeat.2", "dialogue:marlon.defeat.3"},
  },
  [315] = {
    encounter = {"dialogue:shauntal.encounter.1", "dialogue:shauntal.encounter.2", "dialogue:shauntal.encounter.3"},
    victory = {"dialogue:shauntal.victory.1", "dialogue:shauntal.victory.2", "dialogue:shauntal.victory.3"},
    defeat = {"dialogue:shauntal.defeat.1", "dialogue:shauntal.defeat.2", "dialogue:shauntal.defeat.3"},
  },
  [316] = {
    encounter = {"dialogue:marshal.encounter.1", "dialogue:marshal.encounter.2", "dialogue:marshal.encounter.3"},
    victory = {"dialogue:marshal.victory.1", "dialogue:marshal.victory.2", "dialogue:marshal.victory.3"},
    defeat = {"dialogue:marshal.defeat.1", "dialogue:marshal.defeat.2", "dialogue:marshal.defeat.3"},
  },
  [236] = {
    encounter = {"dialogue:cheren.encounter.1", "dialogue:cheren.encounter.2", "dialogue:cheren.encounter.3"},
    victory = {"dialogue:cheren.victory.1", "dialogue:cheren.victory.2", "dialogue:cheren.victory.3"},
    defeat = {"dialogue:cheren.defeat.1", "dialogue:cheren.defeat.2", "dialogue:cheren.defeat.3"},
  },
  [234] = {
    encounter = {"dialogue:chili.encounter.1", "dialogue:chili.encounter.2", "dialogue:chili.encounter.3"},
    victory = {"dialogue:chili.victory.1", "dialogue:chili.victory.2", "dialogue:chili.victory.3"},
    defeat = {"dialogue:chili.defeat.1", "dialogue:chili.defeat.2", "dialogue:chili.defeat.3"},
  },
  [233] = {
    encounter = {"dialogue:cilan.encounter.1", "dialogue:cilan.encounter.2", "dialogue:cilan.encounter.3"},
    victory = {"dialogue:cilan.victory.1", "dialogue:cilan.victory.2", "dialogue:cilan.victory.3"},
    defeat = {"dialogue:cilan.defeat.1", "dialogue:cilan.defeat.2", "dialogue:cilan.defeat.3"},
  },
  [225] = {
    encounter = {
      "dialogue:roark.encounter.1",
      "dialogue:roark.encounter.2",
      "dialogue:roark.encounter.3",
      "dialogue:roark.encounter.4",
    },
    victory = {
      "dialogue:roark.victory.1",
      "dialogue:roark.victory.2",
      "dialogue:roark.victory.3",
      "dialogue:roark.victory.4",
    },
    defeat = {"dialogue:roark.defeat.1", "dialogue:roark.defeat.2", "dialogue:roark.defeat.3"},
  },
  [211] = {
    encounter = {
      "dialogue:morty.encounter.1",
      "dialogue:morty.encounter.2",
      "dialogue:morty.encounter.3",
      "dialogue:morty.encounter.4",
      "dialogue:morty.encounter.5",
      "dialogue:morty.encounter.6",
    },
    victory = {
      "dialogue:morty.victory.1",
      "dialogue:morty.victory.2",
      "dialogue:morty.victory.3",
      "dialogue:morty.victory.4",
      "dialogue:morty.victory.5",
      "dialogue:morty.victory.6",
    },
    defeat = {
      "dialogue:morty.defeat.1",
      "dialogue:morty.defeat.2",
      "dialogue:morty.defeat.3",
      "dialogue:morty.defeat.4",
      "dialogue:morty.defeat.5",
      "dialogue:morty.defeat.6",
    },
  },
  [337] = {
    encounter = {"dialogue:crispin.encounter.1", "dialogue:crispin.encounter.2"},
    victory = {"dialogue:crispin.victory.1", "dialogue:crispin.victory.2"},
    defeat = {"dialogue:crispin.defeat.1", "dialogue:crispin.defeat.2"},
  },
  [338] = {
    encounter = {"dialogue:amarys.encounter.1"},
    victory = {"dialogue:amarys.victory.1"},
    defeat = {"dialogue:amarys.defeat.1"},
  },
  [339] = {
    encounter = {"dialogue:lacey.encounter.1"},
    victory = {"dialogue:lacey.victory.1"},
    defeat = {"dialogue:lacey.defeat.1"},
  },
  [340] = {
    encounter = {"dialogue:drayton.encounter.1"},
    victory = {"dialogue:drayton.victory.1"},
    defeat = {"dialogue:drayton.defeat.1"},
  },
  [249] = {
    encounter = {"dialogue:ramos.encounter.1"},
    victory = {"dialogue:ramos.victory.1"},
    defeat = {"dialogue:ramos.defeat.1"},
  },
  [246] = {
    encounter = {"dialogue:viola.encounter.1", "dialogue:viola.encounter.2"},
    victory = {"dialogue:viola.victory.1", "dialogue:viola.victory.2"},
    defeat = {"dialogue:viola.defeat.1", "dialogue:viola.defeat.2"},
  },
  [231] = {
    encounter = {"dialogue:candice.encounter.1", "dialogue:candice.encounter.2"},
    victory = {"dialogue:candice.victory.1", "dialogue:candice.victory.2"},
    defeat = {"dialogue:candice.defeat.1", "dialogue:candice.defeat.2"},
  },
  [226] = {
    encounter = {"dialogue:gardenia.encounter.1"},
    victory = {"dialogue:gardenia.victory.1"},
    defeat = {"dialogue:gardenia.defeat.1"},
  },
  [311] = {
    encounter = {"dialogue:aaron.encounter.1"},
    victory = {"dialogue:aaron.victory.1"},
    defeat = {"dialogue:aaron.defeat.1"},
  },
  [235] = {
    encounter = {"dialogue:cress.encounter.1"},
    victory = {"dialogue:cress.victory.1"},
    defeat = {"dialogue:cress.defeat.1"},
  },
  [258] = {
    encounter = {"dialogue:allister.encounter.1"},
    victory = {"dialogue:allister.victory.1"},
    defeat = {"dialogue:allister.defeat.1"},
  },
  [241] = {
    encounter = {"dialogue:clay.encounter.1"},
    victory = {"dialogue:clay.victory.1"},
    defeat = {"dialogue:clay.defeat.1"},
  },
  [269] = {
    encounter = {"dialogue:kofu.encounter.1"},
    victory = {"dialogue:kofu.victory.1"},
    defeat = {"dialogue:kofu.defeat.1"},
  },
  [272] = {
    encounter = {"dialogue:tulip.encounter.1"},
    victory = {"dialogue:tulip.victory.1"},
    defeat = {"dialogue:tulip.defeat.1"},
  },
  [307] = {
    encounter = {"dialogue:sidney.encounter.1"},
    victory = {"dialogue:sidney.victory.1"},
    defeat = {"dialogue:sidney.defeat.1"},
  },
  [308] = {
    encounter = {"dialogue:phoebe.encounter.1"},
    victory = {"dialogue:phoebe.victory.1"},
    defeat = {"dialogue:phoebe.defeat.1"},
  },
  [309] = {
    encounter = {"dialogue:glacia.encounter.1"},
    victory = {"dialogue:glacia.victory.1"},
    defeat = {"dialogue:glacia.defeat.1"},
  },
  [310] = {
    encounter = {"dialogue:drake.encounter.1"},
    victory = {"dialogue:drake.victory.1"},
    defeat = {"dialogue:drake.defeat.1"},
  },
  [354] = {
    encounter = {"dialogue:wallace.encounter.1"},
    victory = {"dialogue:wallace.victory.1"},
    defeat = {"dialogue:wallace.defeat.1"},
  },
  [300] = {
    encounter = {"dialogue:lorelei.encounter.1"},
    victory = {"dialogue:lorelei.victory.1"},
    defeat = {"dialogue:lorelei.defeat.1"},
  },
  [304] = {
    encounter = {"dialogue:will.encounter.1"},
    victory = {"dialogue:will.victory.1"},
    defeat = {"dialogue:will.defeat.1"},
  },
  [319] = {
    encounter = {"dialogue:malva.encounter.1"},
    victory = {"dialogue:malva.victory.1"},
    defeat = {"dialogue:malva.defeat.1"},
  },
  [323] = {
    encounter = {"dialogue:hala.encounter.1"},
    victory = {"dialogue:hala.victory.1"},
    defeat = {"dialogue:hala.defeat.1"},
  },
  [324] = {
    encounter = {"dialogue:molayne.encounter.1"},
    victory = {"dialogue:molayne.victory.1"},
    defeat = {"dialogue:molayne.defeat.1"},
  },
  [333] = {
    encounter = {"dialogue:rika.encounter.1"},
    victory = {"dialogue:rika.victory.1"},
    defeat = {"dialogue:rika.defeat.1"},
  },
  [301] = {
    encounter = {"dialogue:bruno.encounter.1"},
    victory = {"dialogue:bruno.victory.1"},
    defeat = {"dialogue:bruno.defeat.1"},
  },
  [209] = {
    encounter = {"dialogue:bugsy.encounter.1"},
    victory = {"dialogue:bugsy.victory.1"},
    defeat = {"dialogue:bugsy.defeat.1"},
  },
  [305] = {
    encounter = {"dialogue:koga.encounter.1"},
    victory = {"dialogue:koga.victory.1"},
    defeat = {"dialogue:koga.defeat.1"},
  },
  [312] = {
    encounter = {"dialogue:bertha.encounter.1"},
    victory = {"dialogue:bertha.victory.1"},
    defeat = {"dialogue:bertha.defeat.1"},
  },
  [237] = {
    encounter = {"dialogue:lenora.encounter.1"},
    victory = {"dialogue:lenora.victory.1"},
    defeat = {"dialogue:lenora.defeat.1"},
  },
  [320] = {
    encounter = {"dialogue:siebold.encounter.1"},
    victory = {"dialogue:siebold.victory.1"},
    defeat = {"dialogue:siebold.defeat.1"},
  },
  [238] = {
    encounter = {"dialogue:roxie.encounter.1"},
    victory = {"dialogue:roxie.victory.1"},
    defeat = {"dialogue:roxie.defeat.1"},
  },
  [325] = {
    encounter = {"dialogue:olivia.encounter.1"},
    victory = {"dialogue:olivia.victory.1"},
    defeat = {"dialogue:olivia.defeat.1"},
  },
  [334] = {
    encounter = {"dialogue:poppy.encounter.1"},
    victory = {"dialogue:poppy.victory.1"},
    defeat = {"dialogue:poppy.defeat.1"},
  },
  [302] = {
    encounter = {"dialogue:agatha.encounter.1"},
    victory = {"dialogue:agatha.victory.1"},
    defeat = {"dialogue:agatha.defeat.1"},
  },
  [313] = {
    encounter = {"dialogue:flint.encounter.1"},
    victory = {"dialogue:flint.victory.1"},
    defeat = {"dialogue:flint.defeat.1"},
  },
  [317] = {
    encounter = {"dialogue:grimsley.encounter.1"},
    victory = {"dialogue:grimsley.victory.1"},
    defeat = {"dialogue:grimsley.defeat.1"},
  },
  [318] = {
    encounter = {"dialogue:caitlin.encounter.1"},
    victory = {"dialogue:caitlin.victory.1"},
    defeat = {"dialogue:caitlin.defeat.1"},
  },
  [358] = {
    encounter = {"dialogue:diantha.encounter.1"},
    victory = {"dialogue:diantha.victory.1"},
    defeat = {"dialogue:diantha.defeat.1"},
  },
  [321] = {
    encounter = {"dialogue:wikstrom.encounter.1"},
    victory = {"dialogue:wikstrom.victory.1"},
    defeat = {"dialogue:wikstrom.defeat.1"},
  },
  [326] = {
    encounter = {"dialogue:acerola.encounter.1"},
    victory = {"dialogue:acerola.victory.1"},
    defeat = {"dialogue:acerola.defeat.1"},
  },
  [335] = {
    encounter = {"dialogue:larryElite.encounter.1"},
    victory = {"dialogue:larryElite.victory.1"},
    defeat = {"dialogue:larryElite.defeat.1"},
  },
  [303] = {
    encounter = {"dialogue:lance.encounter.1", "dialogue:lance.encounter.2"},
    victory = {"dialogue:lance.victory.1", "dialogue:lance.victory.2"},
    defeat = {"dialogue:lance.defeat.1", "dialogue:lance.defeat.2"},
  },
  [306] = {
    encounter = {"dialogue:karen.encounter.1", "dialogue:karen.encounter.2", "dialogue:karen.encounter.3"},
    victory = {"dialogue:karen.victory.1", "dialogue:karen.victory.2", "dialogue:karen.victory.3"},
    defeat = {"dialogue:karen.defeat.1", "dialogue:karen.defeat.2", "dialogue:karen.defeat.3"},
  },
  [254] = {
    encounter = {"dialogue:milo.encounter.1"},
    victory = {"dialogue:milo.victory.1"},
    defeat = {"dialogue:milo.defeat.1"},
  },
  [314] = {
    encounter = {"dialogue:lucian.encounter.1"},
    victory = {"dialogue:lucian.victory.1"},
    defeat = {"dialogue:lucian.defeat.1"},
  },
  [322] = {
    encounter = {"dialogue:drasna.encounter.1"},
    victory = {"dialogue:drasna.victory.1"},
    defeat = {"dialogue:drasna.defeat.1"},
  },
  [327] = {
    encounter = {"dialogue:kahili.encounter.1"},
    victory = {"dialogue:kahili.victory.1"},
    defeat = {"dialogue:kahili.defeat.1"},
  },
  [336] = {
    encounter = {"dialogue:hassel.encounter.1"},
    victory = {"dialogue:hassel.victory.1"},
    defeat = {"dialogue:hassel.defeat.1"},
  },
  [350] = {
    encounter = {"dialogue:blue.encounter.1"},
    victory = {"dialogue:blue.victory.1"},
    defeat = {"dialogue:blue.defeat.1"},
  },
  [263] = {
    encounter = {"dialogue:piers.encounter.1"},
    victory = {"dialogue:piers.victory.1"},
    defeat = {"dialogue:piers.defeat.1"},
  },
  [351] = {
    encounter = {"dialogue:red.encounter.1"},
    victory = {"dialogue:red.victory.1"},
    defeat = {"dialogue:red.defeat.1"},
  },
  [213] = {
    encounter = {"dialogue:jasmine.encounter.1"},
    victory = {"dialogue:jasmine.victory.1"},
    defeat = {"dialogue:jasmine.defeat.1"},
  },
  [352] = {
    encounter = {"dialogue:lanceChampion.encounter.1"},
    victory = {"dialogue:lanceChampion.victory.1"},
    defeat = {"dialogue:lanceChampion.defeat.1"},
  },
  [353] = {
    encounter = {"dialogue:steven.encounter.1"},
    victory = {"dialogue:steven.victory.1"},
    defeat = {"dialogue:steven.defeat.1"},
  },
  [355] = {
    encounter = {"dialogue:cynthia.encounter.1"},
    victory = {"dialogue:cynthia.victory.1"},
    defeat = {"dialogue:cynthia.defeat.1"},
  },
  [357] = {
    encounter = {"dialogue:iris.encounter.1"},
    victory = {"dialogue:iris.victory.1"},
    defeat = {"dialogue:iris.defeat.1"},
  },
  [359] = {
    encounter = {"dialogue:kukui.encounter.1"},
    victory = {"dialogue:kukui.victory.1"},
    defeat = {"dialogue:kukui.defeat.1"},
  },
  [360] = {
    encounter = {"dialogue:hau.encounter.1"},
    victory = {"dialogue:hau.victory.1"},
    defeat = {"dialogue:hau.defeat.1"},
  },
  [363] = {
    encounter = {"dialogue:geeta.encounter.1"},
    victory = {"dialogue:geeta.victory.1"},
    defeat = {"dialogue:geeta.defeat.1"},
  },
  [364] = {
    encounter = {"dialogue:nemona.encounter.1"},
    victory = {"dialogue:nemona.victory.1"},
    defeat = {"dialogue:nemona.defeat.1"},
  },
  [361] = {
    encounter = {"dialogue:leon.encounter.1"},
    victory = {"dialogue:leon.victory.1"},
    defeat = {"dialogue:leon.defeat.1"},
  },
  [362] = {
    encounter = {"dialogue:mustard.encounter.1"},
    victory = {"dialogue:mustard.victory.1"},
    defeat = {"dialogue:mustard.defeat.1"},
  },
  [210] = {
    encounter = {"dialogue:whitney.encounter.1"},
    victory = {"dialogue:whitney.victory.1"},
    defeat = {"dialogue:whitney.defeat.1"},
  },
  [212] = {
    encounter = {"dialogue:chuck.encounter.1"},
    victory = {"dialogue:chuck.victory.1"},
    defeat = {"dialogue:chuck.defeat.1"},
  },
  [266] = {
    encounter = {"dialogue:katy.encounter.1"},
    victory = {"dialogue:katy.victory.1"},
    defeat = {"dialogue:katy.defeat.1"},
  },
  [214] = {
    encounter = {"dialogue:pryce.encounter.1"},
    victory = {"dialogue:pryce.victory.1"},
    defeat = {"dialogue:pryce.defeat.1"},
  },
  [215] = {
    encounter = {"dialogue:clair.encounter.1"},
    victory = {"dialogue:clair.victory.1"},
    defeat = {"dialogue:clair.defeat.1"},
  },
  [227] = {
    encounter = {"dialogue:maylene.encounter.1"},
    victory = {"dialogue:maylene.victory.1"},
    defeat = {"dialogue:maylene.defeat.1"},
  },
  [229] = {
    encounter = {"dialogue:fantina.encounter.1"},
    victory = {"dialogue:fantina.victory.1"},
    defeat = {"dialogue:fantina.defeat.1"},
  },
  [230] = {
    encounter = {"dialogue:byron.encounter.1"},
    victory = {"dialogue:byron.victory.1"},
    defeat = {"dialogue:byron.defeat.1"},
  },
  [252] = {
    encounter = {"dialogue:olympia.encounter.1"},
    victory = {"dialogue:olympia.victory.1"},
    defeat = {"dialogue:olympia.defeat.1"},
  },
  [232] = {
    encounter = {"dialogue:volkner.encounter.1"},
    victory = {"dialogue:volkner.victory.1"},
    defeat = {"dialogue:volkner.defeat.1"},
  },
  [239] = {
    encounter = {"dialogue:burgh.encounter.1", "dialogue:burgh.encounter.2"},
    victory = {"dialogue:burgh.victory.1", "dialogue:burgh.victory.2"},
    defeat = {"dialogue:burgh.defeat.1", "dialogue:burgh.defeat.2"},
  },
  [240] = {
    encounter = {"dialogue:elesa.encounter.1"},
    victory = {"dialogue:elesa.victory.1"},
    defeat = {"dialogue:elesa.defeat.1"},
  },
  [242] = {
    encounter = {"dialogue:skyla.encounter.1"},
    victory = {"dialogue:skyla.victory.1"},
    defeat = {"dialogue:skyla.defeat.1"},
  },
  [243] = {
    encounter = {"dialogue:brycen.encounter.1"},
    victory = {"dialogue:brycen.victory.1"},
    defeat = {"dialogue:brycen.defeat.1"},
  },
  [244] = {
    encounter = {"dialogue:drayden.encounter.1"},
    victory = {"dialogue:drayden.victory.1"},
    defeat = {"dialogue:drayden.defeat.1"},
  },
  [247] = {
    encounter = {"dialogue:grant.encounter.1"},
    victory = {"dialogue:grant.victory.1"},
    defeat = {"dialogue:grant.defeat.1"},
  },
  [248] = {
    encounter = {"dialogue:korrina.encounter.1"},
    victory = {"dialogue:korrina.victory.1"},
    defeat = {"dialogue:korrina.defeat.1"},
  },
  [250] = {
    encounter = {"dialogue:clemont.encounter.1"},
    victory = {"dialogue:clemont.victory.1"},
    defeat = {"dialogue:clemont.defeat.1"},
  },
  [251] = {
    encounter = {"dialogue:valerie.encounter.1"},
    victory = {"dialogue:valerie.victory.1"},
    defeat = {"dialogue:valerie.defeat.1"},
  },
  [253] = {
    encounter = {"dialogue:wulfric.encounter.1"},
    victory = {"dialogue:wulfric.victory.1"},
    defeat = {"dialogue:wulfric.defeat.1"},
  },
  [256] = {
    encounter = {"dialogue:kabu.encounter.1"},
    victory = {"dialogue:kabu.victory.1"},
    defeat = {"dialogue:kabu.defeat.1"},
  },
  [257] = {
    encounter = {"dialogue:bea.encounter.1"},
    victory = {"dialogue:bea.victory.1"},
    defeat = {"dialogue:bea.defeat.1"},
  },
  [259] = {
    encounter = {"dialogue:opal.encounter.1"},
    victory = {"dialogue:opal.victory.1"},
    defeat = {"dialogue:opal.defeat.1"},
  },
  [260] = {
    encounter = {"dialogue:bede.encounter.1"},
    victory = {"dialogue:bede.victory.1"},
    defeat = {"dialogue:bede.defeat.1"},
  },
  [261] = {
    encounter = {"dialogue:gordie.encounter.1"},
    victory = {"dialogue:gordie.victory.1"},
    defeat = {"dialogue:gordie.defeat.1"},
  },
  [264] = {
    encounter = {"dialogue:marnie.encounter.1"},
    victory = {"dialogue:marnie.victory.1"},
    defeat = {"dialogue:marnie.defeat.1"},
  },
  [265] = {
    encounter = {"dialogue:raihan.encounter.1"},
    victory = {"dialogue:raihan.victory.1"},
    defeat = {"dialogue:raihan.defeat.1"},
  },
  [267] = {
    encounter = {"dialogue:brassius.encounter.1"},
    victory = {"dialogue:brassius.victory.1"},
    defeat = {"dialogue:brassius.defeat.1"},
  },
  [268] = {
    encounter = {"dialogue:iono.encounter.1"},
    victory = {"dialogue:iono.victory.1"},
    defeat = {"dialogue:iono.defeat.1"},
  },
  [270] = {
    encounter = {"dialogue:larry.encounter.1"},
    victory = {"dialogue:larry.victory.1"},
    defeat = {"dialogue:larry.defeat.1"},
  },
  [271] = {
    encounter = {"dialogue:ryme.encounter.1"},
    victory = {"dialogue:ryme.victory.1"},
    defeat = {"dialogue:ryme.defeat.1"},
  },
  [273] = {
    encounter = {"dialogue:grusha.encounter.1"},
    victory = {"dialogue:grusha.victory.1"},
    defeat = {"dialogue:grusha.defeat.1"},
  },
  [328] = {
    encounter = {"dialogue:marnieElite.encounter.1", "dialogue:marnieElite.encounter.2"},
    victory = {"dialogue:marnieElite.victory.1", "dialogue:marnieElite.victory.2"},
    defeat = {"dialogue:marnieElite.defeat.1", "dialogue:marnieElite.defeat.2"},
  },
  [329] = {
    encounter = {"dialogue:nessaElite.encounter.1", "dialogue:nessaElite.encounter.2"},
    victory = {"dialogue:nessaElite.victory.1", "dialogue:nessaElite.victory.2"},
    defeat = {"dialogue:nessaElite.defeat.1", "dialogue:nessaElite.defeat.2"},
  },
  [330] = {
    encounter = {"dialogue:beaElite.encounter.1", "dialogue:beaElite.encounter.2"},
    victory = {"dialogue:beaElite.victory.1", "dialogue:beaElite.victory.2"},
    defeat = {"dialogue:beaElite.defeat.1", "dialogue:beaElite.defeat.2"},
  },
  [331] = {
    encounter = {"dialogue:allisterElite.encounter.1", "dialogue:allisterElite.encounter.2"},
    victory = {"dialogue:allisterElite.victory.1", "dialogue:allisterElite.victory.2"},
    defeat = {"dialogue:allisterElite.defeat.1", "dialogue:allisterElite.defeat.2"},
  },
  [332] = {
    encounter = {"dialogue:raihanElite.encounter.1", "dialogue:raihanElite.encounter.2"},
    victory = {"dialogue:raihanElite.victory.1", "dialogue:raihanElite.victory.2"},
    defeat = {"dialogue:raihanElite.defeat.1", "dialogue:raihanElite.defeat.2"},
  },
  [356] = {
    encounter = {"dialogue:alder.encounter.1"},
    victory = {"dialogue:alder.victory.1"},
    defeat = {"dialogue:alder.defeat.1"},
  },
  [365] = {
    encounter = {"dialogue:kieran.encounter.1"},
    victory = {"dialogue:kieran.victory.1"},
    defeat = {"dialogue:kieran.defeat.1"},
  },
  [375] = {
    {
      encounter = {"dialogue:rival.encounter.1"},
      victory = {"dialogue:rival.victory.1"},
    },
    {
      encounter = {"dialogue:rivalFemale.encounter.1"},
      victory = {"dialogue:rivalFemale.victory.1"},
    },
  },
  [376] = {
    {
      encounter = {"dialogue:rival2.encounter.1"},
      victory = {"dialogue:rival2.victory.1"},
    },
    {
      encounter = {"dialogue:rival2Female.encounter.1"},
      victory = {"dialogue:rival2Female.victory.1"},
      defeat = {"dialogue:rival2Female.defeat.1"},
    },
  },
  [377] = {
    {
      encounter = {"dialogue:rival3.encounter.1"},
      victory = {"dialogue:rival3.victory.1"},
    },
    {
      encounter = {"dialogue:rival3Female.encounter.1"},
      victory = {"dialogue:rival3Female.victory.1"},
      defeat = {"dialogue:rival3Female.defeat.1"},
    },
  },
  [378] = {
    {
      encounter = {"dialogue:rival4.encounter.1"},
      victory = {"dialogue:rival4.victory.1"},
    },
    {
      encounter = {"dialogue:rival4Female.encounter.1"},
      victory = {"dialogue:rival4Female.victory.1"},
      defeat = {"dialogue:rival4Female.defeat.1"},
    },
  },
  [379] = {
    {
      encounter = {"dialogue:rival5.encounter.1"},
      victory = {"dialogue:rival5.victory.1"},
    },
    {
      encounter = {"dialogue:rival5Female.encounter.1"},
      victory = {"dialogue:rival5Female.victory.1"},
      defeat = {"dialogue:rival5Female.defeat.1"},
    },
  },
  [380] = {
    {
      encounter = {"dialogue:rival6.encounter.1"},
      victory = {"dialogue:rival6.victory.1"},
    },
    {
      encounter = {"dialogue:rival6Female.encounter.1"},
      victory = {"dialogue:rival6Female.victory.1"},
    },
  },
};

--[[
  SPEAKER NAME MAPPING
  Maps TrainerType enum to i18n speaker keys
  Source: src/data/mystery-encounters (speaker attribution pattern)
]]
local TRAINER_SPEAKERS = {
  [1] = "aceTrainer",
  [2] = "artist",
  [4] = "backpacker",
  [5] = "baker",
  [6] = "beauty",
  [7] = "biker",
  [8] = {"blackBelt", "battleGirl"}, -- blackBelt/battleGirl
  [9] = {"breeder", "breederFemale"}, -- breeder/breederFemale
  [10] = {"clerk", "clerkFemale"}, -- clerk/clerkFemale
  [11] = "cyclist",
  [15] = "firebreather",
  [16] = {"fisherman", "fishermanFemale"}, -- fisherman/fishermanFemale
  [17] = "guitarist",
  [19] = "hiker",
  [20] = "hooligans",
  [26] = "musician",
  [27] = "hexManiac",
  [29] = "officer",
  [30] = "parasolLady",
  [31] = "pilot",
  [32] = {"pokefan", "pokefanFemale"}, -- pokefan/pokefanFemale
  [34] = "psychic",
  [35] = "ranger",
  [36] = {"rich", "richFemale"}, -- rich/richFemale
  [37] = {"richKid", "richKidFemale"}, -- richKid/richKidFemale
  [39] = "sailor",
  [40] = "scientist",
  [42] = {"snowWorker", "snowWorkerDouble"}, -- snowWorker/snowWorkerDouble
  [44] = "schoolKid",
  [45] = "swimmer",
  [46] = "twins",
  [49] = {"worker", "workerFemale", "workerDouble"}, -- worker/workerFemale/workerDouble
  [50] = {"youngster", "lass"}, -- youngster/lass
  [51] = "rocketGrunt",
  [52] = "archer",
  [53] = "ariana",
  [54] = "proton",
  [55] = "petrel",
  [56] = "magmaGrunt",
  [57] = "tabitha",
  [58] = "courtney",
  [59] = "aquaGrunt",
  [60] = "matt",
  [61] = "shelly",
  [62] = "galacticGrunt",
  [63] = "jupiter",
  [64] = "mars",
  [65] = "saturn",
  [66] = "plasmaGrunt",
  [67] = "zinzolin",
  [68] = "colress",
  [69] = "flareGrunt",
  [70] = "bryony",
  [71] = "xerosic",
  [72] = "aetherGrunt",
  [73] = "faba",
  [74] = "skullGrunt",
  [75] = "plumeria",
  [76] = "macroGrunt",
  [77] = "oleana",
  [78] = "starGrunt",
  [79] = "giacomo",
  [80] = "mela",
  [81] = "atticus",
  [82] = "ortega",
  [83] = "eri",
  [84] = "rocketBossGiovanni1",
  [85] = "rocketBossGiovanni2",
  [86] = "magmaBossMaxie1",
  [87] = "magmaBossMaxie2",
  [88] = "aquaBossArchie1",
  [89] = "aquaBossArchie2",
  [90] = "galacticBossCyrus1",
  [91] = "galacticBossCyrus2",
  [92] = "plasmaBossGhetsis1",
  [93] = "plasmaBossGhetsis2",
  [94] = "flareBossLysandre1",
  [95] = "flareBossLysandre2",
  [96] = "aetherBossLusamine1",
  [97] = "aetherBossLusamine2",
  [98] = "skullBossGuzma1",
  [99] = "skullBossGuzma2",
  [100] = "macroBossRose1",
  [101] = "macroBossRose2",
  [102] = "starBossPenny1",
  [103] = "starBossPenny2",
  [104] = "statTrainerBuck",
  [105] = "statTrainerCheryl",
  [106] = "statTrainerMarley",
  [107] = "statTrainerMira",
  [108] = "statTrainerRiley",
  [109] = "winstratesVictor",
  [110] = "winstratesVictoria",
  [111] = "winstratesVivi",
  [112] = "winstratesVicky",
  [113] = "winstratesVito",
  [200] = "brock",
  [201] = "misty",
  [202] = "ltSurge",
  [203] = "erika",
  [204] = "janine",
  [205] = "sabrina",
  [206] = "blaine",
  [207] = "giovanni",
  [208] = "falkner",
  [209] = "bugsy",
  [210] = "whitney",
  [211] = "morty",
  [212] = "chuck",
  [213] = "jasmine",
  [214] = "pryce",
  [215] = "clair",
  [216] = "roxanne",
  [217] = "brawly",
  [218] = "wattson",
  [219] = "flannery",
  [220] = "norman",
  [221] = "winona",
  [222] = "tate",
  [223] = "liza",
  [224] = "juan",
  [225] = "roark",
  [226] = "gardenia",
  [227] = "maylene",
  [228] = "crasherWake",
  [229] = "fantina",
  [230] = "byron",
  [231] = "candice",
  [232] = "volkner",
  [233] = "cilan",
  [234] = "chili",
  [235] = "cress",
  [236] = "cheren",
  [237] = "lenora",
  [238] = "roxie",
  [239] = "burgh",
  [240] = "elesa",
  [241] = "clay",
  [242] = "skyla",
  [243] = "brycen",
  [244] = "drayden",
  [245] = "marlon",
  [246] = "viola",
  [247] = "grant",
  [248] = "korrina",
  [249] = "ramos",
  [250] = "clemont",
  [251] = "valerie",
  [252] = "olympia",
  [253] = "wulfric",
  [254] = "milo",
  [255] = "nessa",
  [256] = "kabu",
  [257] = "bea",
  [258] = "allister",
  [259] = "opal",
  [260] = "bede",
  [261] = "gordie",
  [262] = "melony",
  [263] = "piers",
  [264] = "marnie",
  [265] = "raihan",
  [266] = "katy",
  [267] = "brassius",
  [268] = "iono",
  [269] = "kofu",
  [270] = "larry",
  [271] = "ryme",
  [272] = "tulip",
  [273] = "grusha",
  [300] = "lorelei",
  [301] = "bruno",
  [302] = "agatha",
  [303] = "lance",
  [304] = "will",
  [305] = "koga",
  [306] = "karen",
  [307] = "sidney",
  [308] = "phoebe",
  [309] = "glacia",
  [310] = "drake",
  [311] = "aaron",
  [312] = "bertha",
  [313] = "flint",
  [314] = "lucian",
  [315] = "shauntal",
  [316] = "marshal",
  [317] = "grimsley",
  [318] = "caitlin",
  [319] = "malva",
  [320] = "siebold",
  [321] = "wikstrom",
  [322] = "drasna",
  [323] = "hala",
  [324] = "molayne",
  [325] = "olivia",
  [326] = "acerola",
  [327] = "kahili",
  [328] = "marnieElite",
  [329] = "nessaElite",
  [330] = "beaElite",
  [331] = "allisterElite",
  [332] = "raihanElite",
  [333] = "rika",
  [334] = "poppy",
  [335] = "larryElite",
  [336] = "hassel",
  [337] = "crispin",
  [338] = "amarys",
  [339] = "lacey",
  [340] = "drayton",
  [350] = "blue",
  [351] = "red",
  [352] = "lanceChampion",
  [353] = "steven",
  [354] = "wallace",
  [355] = "cynthia",
  [356] = "alder",
  [357] = "iris",
  [358] = "diantha",
  [359] = "kukui",
  [360] = "hau",
  [361] = "leon",
  [362] = "mustard",
  [363] = "geeta",
  [364] = "nemona",
  [365] = "kieran",
  [375] = {"rival", "rivalFemale"}, -- rival/rivalFemale
  [376] = {"rival2", "rival2Female"}, -- rival2/rival2Female
  [377] = {"rival3", "rival3Female"}, -- rival3/rival3Female
  [378] = {"rival4", "rival4Female"}, -- rival4/rival4Female
  [379] = {"rival5", "rival5Female"}, -- rival5/rival5Female
  [380] = {"rival6", "rival6Female"}, -- rival6/rival6Female
}

--[[
  Core Functions
]]

-- Get dialogue variants for specific trainer and phase
-- Returns: dialogue_data (table or nil), error (string or nil)
local function getCharacterDialogue(trainerType, dialoguePhase, variantIndex)
  -- Validate trainer type
  if not trainerType or type(trainerType) ~= "number" then
    return nil, "Invalid trainer type"
  end

  -- Validate dialogue phase
  local validPhases = {encounter = true, victory = true, defeat = true}
  if dialoguePhase and not validPhases[dialoguePhase] then
    return nil, "Invalid dialogue phase: " .. tostring(dialoguePhase)
  end

  -- Get trainer dialogue entry
  local trainerData = TRAINER_DIALOGUE[trainerType]
  if not trainerData then
    return nil, "No dialogue data for trainer type: " .. tostring(trainerType)
  end

  -- Handle variant-based trainers (e.g., Youngster/Lass, Breeder male/female)
  if type(trainerData[1]) == "table" and trainerData[1].encounter then
    -- This trainer has variants
    local variant = variantIndex or 1
    if variant < 1 or variant > #trainerData then
      return nil, "Invalid variant index: " .. tostring(variant) .. " (max: " .. #trainerData .. ")"
    end

    local variantData = trainerData[variant]

    if dialoguePhase then
      -- Return specific phase dialogue
      return variantData[dialoguePhase]
    else
      -- Return all phases for this variant
      return variantData
    end
  else
    -- Direct dialogue (Gym Leaders, Elite Four, Champions)
    if dialoguePhase then
      return trainerData[dialoguePhase]
    else
      return trainerData
    end
  end
end

-- Deterministically select dialogue variant based on seed
-- Returns: dialogue_key (string or nil), variant_index (number or nil), error (string or nil)
local function selectRandomDialogue(trainerType, dialoguePhase, seed, variantIndex)
  -- Get dialogue data for this trainer/phase/variant
  local dialogueData, err = getCharacterDialogue(trainerType, dialoguePhase, variantIndex)

  if not dialogueData then
    return nil, nil, err
  end

  -- If dialogueData is not an array, there's no randomization needed
  if type(dialogueData) ~= "table" or #dialogueData == 0 then
    return nil, nil, "No dialogue variants available"
  end

  -- Use seed for deterministic selection
  -- Simple LCG (Linear Congruential Generator) for deterministic randomness
  -- Formula: (a * seed + c) % m
  local a = 1103515245
  local c = 12345
  local m = 2^31
  local randomValue = ((a * seed + c) % m) / m

  -- Select dialogue index based on random value
  local selectedIndex = math.floor(randomValue * #dialogueData) + 1

  -- Clamp to valid range
  if selectedIndex < 1 then selectedIndex = 1 end
  if selectedIndex > #dialogueData then selectedIndex = #dialogueData end

  return dialogueData[selectedIndex], selectedIndex, nil
end

-- Get speaker i18n key for trainer type
-- Returns: speaker_name (string or nil), error (string or nil)
local function getSpeakerName(trainerType, variantIndex)
  -- Validate trainer type
  if not trainerType or type(trainerType) ~= "number" then
    return nil, "Invalid trainer type"
  end

  -- Get speaker mapping
  local speakerData = TRAINER_SPEAKERS[trainerType]
  if not speakerData then
    return nil, "No speaker mapping for trainer type: " .. tostring(trainerType)
  end

  -- Handle multi-variant speakers (e.g., youngster/lass, breeder male/female)
  if type(speakerData) == "table" then
    local variant = variantIndex or 1
    if variant < 1 or variant > #speakerData then
      return nil, "Invalid variant index: " .. tostring(variant) .. " (max: " .. #speakerData .. ")"
    end
    return speakerData[variant], nil
  else
    -- Single speaker
    return speakerData, nil
  end
end

-- Replace dialogue tokens with context values
-- Reused from Story 19.2 dialogue-navigation-engine.lua
-- Returns: processed_text (string), token_count (number)
local function injectDialogueContext(dialogueText, dialogueTokens)
  if not dialogueText or dialogueText == "" then
    return dialogueText, 0
  end

  if not dialogueTokens then
    dialogueTokens = {}
  end

  local processedText = dialogueText
  local tokenCount = 0

  -- Replace {{tokenName}} with values from dialogueTokens map
  -- Using Lua pattern matching: {{(.-)}} captures token name
  processedText = string.gsub(processedText, "{{(.-)}}",  function(tokenName)
    local tokenValue = dialogueTokens[tokenName]
    if tokenValue ~= nil then
      tokenCount = tokenCount + 1
      return tostring(tokenValue)
    else
      -- Missing token - return placeholder with warning marker
      return "{{" .. tokenName .. "}}"
    end
  end)

  return processedText, tokenCount
end

-- Validate trainer personality has dialogue defined
-- Returns: is_valid (boolean), error (string or nil)
local function validatePersonality(trainerType, dialoguePhase)
  -- Validate trainer type
  if not trainerType or type(trainerType) ~= "number" then
    return false, "Invalid trainer type"
  end

  -- Check if trainer has dialogue data
  local trainerData = TRAINER_DIALOGUE[trainerType]
  if not trainerData then
    return false, "No dialogue data for trainer type: " .. tostring(trainerType)
  end

  -- If phase specified, validate it exists
  if dialoguePhase then
    local validPhases = {encounter = true, victory = true, defeat = true}
    if not validPhases[dialoguePhase] then
      return false, "Invalid dialogue phase: " .. tostring(dialoguePhase)
    end

    -- Check phase availability
    -- Handle variant-based trainers
    if type(trainerData[1]) == "table" and trainerData[1].encounter then
      -- Check first variant for phase availability
      if not trainerData[1][dialoguePhase] then
        return false, "Phase '" .. dialoguePhase .. "' not available for trainer type: " .. tostring(trainerType)
      end
    else
      -- Direct dialogue
      if not trainerData[dialoguePhase] then
        return false, "Phase '" .. dialoguePhase .. "' not available for trainer type: " .. tostring(trainerType)
      end
    end
  end

  return true, nil
end

--[[
  AO Message Handlers
]]

-- Handler: GetCharacterDialogue
Handlers.add("get-character-dialogue",
  Handlers.utils.hasMatchingTag("Action", "GetCharacterDialogue"),
  function(msg)
    local trainerType = tonumber(msg.TrainerType)
    local dialoguePhase = msg.DialoguePhase or "encounter"
    local variantIndex = tonumber(msg.VariantIndex)

    if not trainerType then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "TrainerType required"
      })
      return
    end

    local dialogueData, err = getCharacterDialogue(trainerType, dialoguePhase, variantIndex)

    if not dialogueData then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = err or "Failed to retrieve dialogue"
      })
      return
    end

    -- Get speaker name for the trainer type
    local speakerName, speakerErr = getSpeakerName(trainerType, variantIndex)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      TrainerType = tostring(trainerType),
      DialoguePhase = dialoguePhase,
      VariantIndex = variantIndex and tostring(variantIndex) or "",
      DialogueCount = tostring(#dialogueData),
      Speaker = speakerName or "",
      Data = json.encode(dialogueData)
    })
  end
)

-- Handler: SelectRandomDialogue
Handlers.add("select-random-dialogue",
  Handlers.utils.hasMatchingTag("Action", "SelectRandomDialogue"),
  function(msg)
    local trainerType = tonumber(msg.TrainerType)
    local dialoguePhase = msg.DialoguePhase or "encounter"
    local seed = tonumber(msg.Seed)
    local variantIndex = tonumber(msg.VariantIndex)

    if not trainerType then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "TrainerType required"
      })
      return
    end

    if not seed then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "Seed required for deterministic selection"
      })
      return
    end

    local dialogueKey, selectedIndex, err = selectRandomDialogue(trainerType, dialoguePhase, seed, variantIndex)

    if not dialogueKey then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = err or "Failed to select dialogue"
      })
      return
    end

    -- Get dialogue data to extract variant count
    local dialogueData, _ = getCharacterDialogue(trainerType, dialoguePhase, variantIndex)
    local variantCount = dialogueData and #dialogueData or 0

    -- Get speaker name
    local speakerName, _ = getSpeakerName(trainerType, variantIndex)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      TrainerType = tostring(trainerType),
      DialoguePhase = dialoguePhase,
      Seed = tostring(seed),
      VariantIndex = tostring(selectedIndex),
      VariantCount = tostring(variantCount),
      Speaker = speakerName or "",
      DialogueKey = dialogueKey
    })
  end
)

-- Handler: GetSpeakerName
Handlers.add("get-speaker-name",
  Handlers.utils.hasMatchingTag("Action", "GetSpeakerName"),
  function(msg)
    local trainerType = tonumber(msg.TrainerType)
    local variantIndex = tonumber(msg.VariantIndex)

    if not trainerType then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "TrainerType required"
      })
      return
    end

    local speakerName, err = getSpeakerName(trainerType, variantIndex)

    if not speakerName then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = err or "Failed to get speaker name"
      })
      return
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      TrainerType = tostring(trainerType),
      VariantIndex = variantIndex and tostring(variantIndex) or "",
      SpeakerKey = speakerName
    })
  end
)

-- Handler: InjectDialogueContext
Handlers.add("inject-dialogue-context",
  Handlers.utils.hasMatchingTag("Action", "InjectDialogueContext"),
  function(msg)
    local dialogueText = msg.DialogueText
    local dialogueTokensJson = msg.Data

    if not dialogueText then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "DialogueText required"
      })
      return
    end

    -- Parse dialogue tokens from Data field
    local dialogueTokens = {}
    if dialogueTokensJson and dialogueTokensJson ~= "" then
      dialogueTokens = json.decode(dialogueTokensJson)
    end

    -- Process token replacement
    local processedText, tokenCount = injectDialogueContext(dialogueText, dialogueTokens)

    -- Send successful response
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      TokenCount = tostring(tokenCount),
      Data = processedText
    })
  end
)

-- Handler: ValidatePersonality
Handlers.add("validate-personality",
  Handlers.utils.hasMatchingTag("Action", "ValidatePersonality"),
  function(msg)
    local trainerType = tonumber(msg.TrainerType)
    local dialoguePhase = msg.DialoguePhase or "encounter"

    if not trainerType then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "TrainerType required"
      })
      return
    end

    local isValid, err = validatePersonality(trainerType, dialoguePhase)

    -- Get dialogue data to extract variant count (even if validation fails)
    local dialogueData, _ = getCharacterDialogue(trainerType, dialoguePhase, nil)
    local variantCount = dialogueData and #dialogueData or 0
    local hasDialogue = variantCount > 0

    -- Always send SaveState with validation result
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = tostring(isValid),
      TrainerType = tostring(trainerType),
      DialoguePhase = dialoguePhase,
      Valid = tostring(isValid),
      HasDialogue = tostring(hasDialogue),
      VariantCount = tostring(variantCount),
      Error = not isValid and (err or "Validation failed") or ""
    })
  end
)

-- Handler: ListAvailablePersonalities
Handlers.add("list-available-personalities",
  Handlers.utils.hasMatchingTag("Action", "ListAvailablePersonalities"),
  function(msg)
    -- Build personality list with variant counts
    local personalities = {}

    for trainerType, dialogueData in pairs(TRAINER_DIALOGUE) do
      local personalityInfo = {
        trainerType = trainerType,
        variantCount = 1,
        phases = {}
      }

      -- Determine variant count and available phases
      if type(dialogueData[1]) == "table" and dialogueData[1].encounter then
        -- Variant-based trainer
        personalityInfo.variantCount = #dialogueData

        -- Get phases from first variant
        for phase, _ in pairs(dialogueData[1]) do
          table.insert(personalityInfo.phases, phase)
        end
      else
        -- Direct dialogue trainer
        for phase, _ in pairs(dialogueData) do
          table.insert(personalityInfo.phases, phase)
        end
      end

      table.insert(personalities, personalityInfo)
    end

    -- Send response
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      PersonalityCount = tostring(#personalities),
      Data = json.encode(personalities)
    })
  end
)

-- Handler: Info (ADP v1.0 Compliance)
Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    local processInfo = {
      process = {
        name = "Character Dialogue Engine",
        version = "1.0.0",
        adpVersion = "1.0",
        processId = ao.id or "character-dialogue-engine-adp",
        epic = "Epic 19 - Mystery Encounter System",
        story = "19.3 - Character Dialogue Generation Migration",
        capabilities = {
          "GetCharacterDialogue",
          "SelectRandomDialogue",
          "GetSpeakerName",
          "InjectDialogueContext",
          "ValidatePersonality",
          "ListAvailablePersonalities"
        },
        messageSchemas = {
          GetCharacterDialogue = {
            required = {"Action", "TrainerType"},
            optional = {"DialoguePhase", "VariantIndex"},
            description = "Retrieve personality-appropriate dialogue for specific trainer type and phase"
          },
          SelectRandomDialogue = {
            required = {"Action", "TrainerType", "Seed"},
            optional = {"DialoguePhase"},
            description = "Deterministically select dialogue variant based on seed"
          },
          GetSpeakerName = {
            required = {"Action", "TrainerType"},
            optional = {"VariantIndex"},
            description = "Map TrainerType to speaker i18n key for UI rendering"
          },
          InjectDialogueContext = {
            required = {"Action", "DialogueText"},
            optional = {"Data"},
            description = "Replace dialogue tokens with game-specific context values"
          },
          ValidatePersonality = {
            required = {"Action", "TrainerType"},
            optional = {"DialoguePhase"},
            description = "Verify trainer type has dialogue defined for requested phase"
          },
          ListAvailablePersonalities = {
            required = {"Action"},
            optional = {},
            description = "Enumerate all defined character personalities with variant counts"
          }
        }
      },
      handlers = {
        "GetCharacterDialogue",
        "SelectRandomDialogue",
        "GetSpeakerName",
        "InjectDialogueContext",
        "ValidatePersonality",
        "ListAvailablePersonalities",
        "Info"
      },
      documentation = {
        adpCompliance = "v1.0",
        selfDocumenting = true,
        personalityCount = 233, -- 233 trainer types with dialogue data
        totalDialogueVariants = 1698, -- Total dialogue entries across all personalities
        embeddedDataSize = "~67KB" -- Embedded dialogue database size
      }
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(processInfo)
    })
  end
)

-- Process initialization
print("Character Dialogue Engine initialized. ADP v1.0 compliant.")
