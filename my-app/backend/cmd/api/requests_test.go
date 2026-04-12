package main

import "testing"

func TestHelperPoolCandidateStatuses(t *testing.T) {
	t.Parallel()

	statuses := helperPoolCandidateStatuses()
	if len(statuses) != 3 {
		t.Fatalf("len(helperPoolCandidateStatuses()) = %d, want 3", len(statuses))
	}
	if statuses[0] != "pending" {
		t.Fatalf("helperPoolCandidateStatuses()[0] = %q, want %q", statuses[0], "pending")
	}
	if statuses[1] != "cancelled" {
		t.Fatalf("helperPoolCandidateStatuses()[1] = %q, want %q", statuses[1], "cancelled")
	}
	if statuses[2] != "canceled" {
		t.Fatalf("helperPoolCandidateStatuses()[2] = %q, want %q", statuses[2], "canceled")
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
		{ID: "cancelled-returned-from-helper", Status: "cancelled", HelperID: "helper-3", CanceledHelperIDs: []string{"helper-3"}},
	}

	filtered := filterHelperVisiblePendingRequests(requests, helperID)
	if len(filtered) != 5 {
		t.Fatalf("len(filterHelperVisiblePendingRequests()) = %d, want 5", len(filtered))
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
	if filtered[3].Status != "pending" {
		t.Fatalf("filtered[3].Status = %q, want %q", filtered[3].Status, "pending")
	}
	if filtered[4].ID != "cancelled-returned-from-helper" {
		t.Fatalf("filtered[4].ID = %q, want %q", filtered[4].ID, "cancelled-returned-from-helper")
	}
	if filtered[4].Status != "pending" {
		t.Fatalf("filtered[4].Status = %q, want %q", filtered[4].Status, "pending")
	}
}

func TestRequestReturnsToHelperPool(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name    string
		request RecyclingRequest
		want    bool
	}{
		{
			name:    "pending request",
			request: RecyclingRequest{Status: "pending"},
			want:    true,
		},
		{
			name:    "cancelled unassigned request",
			request: RecyclingRequest{Status: "cancelled"},
			want:    true,
		},
		{
			name:    "cancelled request returned by helper",
			request: RecyclingRequest{Status: "cancelled", HelperID: "helper-1", CanceledHelperIDs: []string{"helper-1"}},
			want:    true,
		},
		{
			name:    "cancelled request with stale helper assignment but recorded cancellation",
			request: RecyclingRequest{Status: "cancelled", HelperID: " helper-1 ", CanceledHelperIDs: []string{"helper-9", "HELPER-1"}},
			want:    true,
		},
		{
			name:    "cancelled request with active helper",
			request: RecyclingRequest{Status: "cancelled", HelperID: "helper-1"},
			want:    false,
		},
		{
			name:    "canceled request returned by helper",
			request: RecyclingRequest{Status: "canceled", HelperID: "helper-1", CanceledHelperIDs: []string{"helper-1"}},
			want:    true,
		},
		{
			name:    "canceled request with active helper",
			request: RecyclingRequest{Status: "canceled", HelperID: "helper-1"},
			want:    false,
		},
		{
			name:    "accepted request",
			request: RecyclingRequest{Status: "accepted", HelperID: "helper-1"},
			want:    false,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			got := requestReturnsToHelperPool(tc.request)
			if got != tc.want {
				t.Fatalf("requestReturnsToHelperPool(%+v) = %t, want %t", tc.request, got, tc.want)
			}
		})
	}
}

func TestHelperCancellationRecorded(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name    string
		request RecyclingRequest
		want    bool
	}{
		{
			name:    "matches helper assignment",
			request: RecyclingRequest{HelperID: "helper-1", CanceledHelperIDs: []string{"helper-2", "HELPER-1"}},
			want:    true,
		},
		{
			name:    "records cancellation without helper assignment",
			request: RecyclingRequest{CanceledHelperIDs: []string{"helper-1"}},
			want:    true,
		},
		{
			name:    "ignores empty cancellation list",
			request: RecyclingRequest{HelperID: "helper-1"},
			want:    false,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			got := helperCancellationRecorded(tc.request)
			if got != tc.want {
				t.Fatalf("helperCancellationRecorded(%+v) = %t, want %t", tc.request, got, tc.want)
			}
		})
	}
}

func TestFilterHelperAssignedRequests(t *testing.T) {
	t.Parallel()

	helperID := "helper-2"
	requests := []RecyclingRequest{
		{ID: "accepted-self", Status: "accepted", HelperID: helperID},
		{ID: "accepted-other", Status: "accepted", HelperID: "helper-1"},
		{ID: "pending-returned-to-pool", Status: "pending", HelperID: helperID},
		{ID: "cancelled-returned-to-pool", Status: "cancelled", HelperID: helperID, CanceledHelperIDs: []string{helperID}},
		{ID: "cancelled-returned-to-pool-mixed-case", Status: "cancelled", HelperID: " HELPER-2 ", CanceledHelperIDs: []string{helperID}},
	}

	filtered := filterHelperAssignedRequests(requests, helperID)
	if len(filtered) != 1 {
		t.Fatalf("len(filterHelperAssignedRequests()) = %d, want 1", len(filtered))
	}
	if filtered[0].ID != "accepted-self" {
		t.Fatalf("filtered[0].ID = %q, want %q", filtered[0].ID, "accepted-self")
	}
}
