package main

import "testing"

func TestFilterHelperVisiblePendingRequests(t *testing.T) {
	t.Parallel()

	helperID := "helper-2"
	requests := []RecyclingRequest{
		{ID: "pool-pending", Status: "pending"},
		{ID: "cancelled-by-other", Status: "pending", CanceledHelperIDs: []string{"helper-1"}},
		{ID: "cancelled-by-current", Status: "pending", CanceledHelperIDs: []string{"helper-2"}},
		{ID: "accepted", Status: "accepted", HelperID: helperID},
	}

	filtered := filterHelperVisiblePendingRequests(requests, helperID)
	if len(filtered) != 2 {
		t.Fatalf("len(filterHelperVisiblePendingRequests()) = %d, want 2", len(filtered))
	}
	if filtered[0].ID != "pool-pending" {
		t.Fatalf("filtered[0].ID = %q, want %q", filtered[0].ID, "pool-pending")
	}
	if filtered[1].ID != "cancelled-by-other" {
		t.Fatalf("filtered[1].ID = %q, want %q", filtered[1].ID, "cancelled-by-other")
	}
}

func TestFilterHelperAssignedRequests(t *testing.T) {
	t.Parallel()

	helperID := "helper-2"
	requests := []RecyclingRequest{
		{ID: "accepted-self", Status: "accepted", HelperID: helperID},
		{ID: "accepted-other", Status: "accepted", HelperID: "helper-1"},
		{ID: "pending", Status: "pending", HelperID: helperID},
	}

	filtered := filterHelperAssignedRequests(requests, helperID)
	if len(filtered) != 2 {
		t.Fatalf("len(filterHelperAssignedRequests()) = %d, want 2", len(filtered))
	}
	if filtered[0].ID != "accepted-self" {
		t.Fatalf("filtered[0].ID = %q, want %q", filtered[0].ID, "accepted-self")
	}
	if filtered[1].ID != "pending" {
		t.Fatalf("filtered[1].ID = %q, want %q", filtered[1].ID, "pending")
	}
}
