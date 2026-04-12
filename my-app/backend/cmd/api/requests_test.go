package main

import "testing"

func TestHelperPoolCandidateStatuses(t *testing.T) {
	t.Parallel()

	statuses := helperPoolCandidateStatuses()
	if len(statuses) != 2 {
		t.Fatalf("len(helperPoolCandidateStatuses()) = %d, want 2", len(statuses))
	}
	if statuses[0] != "pending" {
		t.Fatalf("helperPoolCandidateStatuses()[0] = %q, want %q", statuses[0], "pending")
	}
	if statuses[1] != "cancelled" {
		t.Fatalf("helperPoolCandidateStatuses()[1] = %q, want %q", statuses[1], "cancelled")
	}
}

func TestFilterHelperVisiblePendingRequests(t *testing.T) {
	t.Parallel()

	helperID := "helper-2"
	requests := []RecyclingRequest{
		{ID: "pool-pending", Status: "pending"},
		{ID: "returned-to-pool", Status: "pending"},
		{ID: "cancelled-but-assigned", Status: "cancelled", HelperID: "helper-3"},
		{ID: "cancelled-by-other", Status: "pending", CanceledHelperIDs: []string{"helper-1"}},
		{ID: "cancelled-by-current", Status: "pending", CanceledHelperIDs: []string{"helper-2"}},
		{ID: "returned-but-blocked-for-current", Status: "pending", CanceledHelperIDs: []string{"helper-2"}},
		{ID: "accepted", Status: "accepted", HelperID: helperID},
		{ID: "cancelled-unassigned", Status: "cancelled"},
	}

	filtered := filterHelperVisiblePendingRequests(requests, helperID)
	if len(filtered) != 4 {
		t.Fatalf("len(filterHelperVisiblePendingRequests()) = %d, want 4", len(filtered))
	}
	if filtered[0].ID != "pool-pending" {
		t.Fatalf("filtered[0].ID = %q, want %q", filtered[0].ID, "pool-pending")
	}
	if filtered[1].ID != "returned-to-pool" {
		t.Fatalf("filtered[1].ID = %q, want %q", filtered[1].ID, "returned-to-pool")
	}
	if filtered[2].ID != "cancelled-by-other" {
		t.Fatalf("filtered[2].ID = %q, want %q", filtered[2].ID, "cancelled-by-other")
	}
	if filtered[3].ID != "cancelled-unassigned" {
		t.Fatalf("filtered[3].ID = %q, want %q", filtered[3].ID, "cancelled-unassigned")
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
