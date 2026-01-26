variable "org_id" {
  description = "Only used to generate API key file"
  type        = string
}

variable "zone_id" {
  description = "Only used to generate API key file"
  type        = string
}

variable "teams" {
  type = map(any)
  default = {
    team01 = {
      name = "THALES SERVICES NUMERIQUES"
      members = [
        "toto@gmail.com",
 
      ]
    }
    team02 = {
      name = "COEXYA"
      members = [
        "toto@gmail.com",

      ]
    }
    team03 = {
      name = "SOPRA STERIA"
      members = [
        "toto@gmail.com",

      ]
    }
    team04 = {
      name = "OCTO"
      members = [
        "toto@gmail.com",

      ]
    }
    team05 = {
      name = "USE & SHARE"
      members = [
        "gderamchi@gmail.com",

      ]
    }
    team06 = {
      name = "CLARANET"
      members = [
        "toto@gmail.com",

      ]
    }
    team07 = {
      name = "ATOS"
      members = [
        "toto.queriaux@edu.ece.fr",
      ]
    }
    team08 = {
      name = "EURANOVA"
      members = [
        "zeynepbilgihan@gmail.com",
      ]
    }
  }
}
