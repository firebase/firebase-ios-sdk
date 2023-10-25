variable "project_id" {}

provider "google" {
  project = var.project_id
}

resource "google_firestore_index" "default_db_index" {
  collection = "composite-index-test-collection"

  for_each = local.indexes
  dynamic "fields" {
    for_each = distinct(flatten([for k, v in local.indexes : [
      for i in each.value : {
        field_path   = i.field_path
        order        = can(i.order) ? i.order : null
        array_config = can(i.array_config) ? i.array_config : null
    }]]))
    content {
      field_path   = fields.value.field_path
      order        = fields.value.order
      array_config = fields.value.array_config
    }
  }
}

resource "google_firestore_index" "default_db_collection_group_index" {
  collection  = "composite-index-test-collection"
  query_scope = "COLLECTION_GROUP"

  for_each = local.collection_group_indexes
  dynamic "fields" {
    for_each = distinct(flatten([for k, v in local.indexes : [
      for i in each.value : {
        field_path   = i.field_path
        order        = can(i.order) ? i.order : null
        array_config = can(i.array_config) ? i.array_config : null
    }]]))
    content {
      field_path   = fields.value.field_path
      order        = fields.value.order
      array_config = fields.value.array_config
    }
  }
}

resource "google_firestore_index" "named_db_index" {
  collection = "composite-index-test-collection"
  database   = "test-db"

  for_each = local.indexes
  dynamic "fields" {
    for_each = distinct(flatten([for k, v in local.indexes : [
      for i in each.value : {
        field_path   = i.field_path
        order        = can(i.order) ? i.order : null
        array_config = can(i.array_config) ? i.array_config : null
    }]]))
    content {
      field_path   = fields.value.field_path
      order        = fields.value.order
      array_config = fields.value.array_config
    }
  }
}

resource "google_firestore_index" "named_db_collection_group_index" {
  collection  = "composite-index-test-collection"
  database    = "test-db"
  query_scope = "COLLECTION_GROUP"

  for_each = local.collection_group_indexes
  dynamic "fields" {
    for_each = distinct(flatten([for k, v in local.indexes : [
      for i in each.value : {
        field_path   = i.field_path
        order        = can(i.order) ? i.order : null
        array_config = can(i.array_config) ? i.array_config : null
    }]]))
    content {
      field_path   = fields.value.field_path
      order        = fields.value.order
      array_config = fields.value.array_config
    }
  }
}
