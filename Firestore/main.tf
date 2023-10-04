variable "project_id" {}

provider "google" {
  project = var.project_id
}

resource "google_firestore_index" "default-db-index" {
  collection = "composite-index-test-collection"

  for_each = local.indexes
  dynamic "fields" {
    for_each = distinct(flatten([for k, v in local.indexes : [
      for i in each.value : {
        field_path = i.field_path
        order      = i.order
    }]]))
    content {
      field_path = lookup(fields.value, "field_path", null)
      order      = lookup(fields.value, "order", null)
    }
  }
}

resource "google_firestore_index" "named-db-index" {
  collection = "composite-index-test-collection"
  database   = "test-db"

  for_each = local.indexes
  dynamic "fields" {
    for_each = distinct(flatten([for k, v in local.indexes : [
      for i in each.value : {
        field_path = i.field_path
        order      = i.order
    }]]))
    content {
      field_path = lookup(fields.value, "field_path", null)
      order      = lookup(fields.value, "order", null)
    }
  }
}
