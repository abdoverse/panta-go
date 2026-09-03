package main

import "testing"

func TestHelperPoolCandidateStatuses(t *testing.T) {
	t.Parallel()

	statuses := helperPoolCandidateStatuses()
	if len(statuses) != 1 {
		t.Fatalf("len(helperPoolCandidateStatuses()) = %d, want 1", len(statuses))
	}
	if statuses[0] != "pending" {
		t.Fatalf("helperPoolCandidateStatuses()[0] = %q, want %q", statuses[0], "pending")
	}
}

func TestFilterHelperVisiblePendingRequests(t *testing.T) {
	t.Parallel()

	helperID := "helper-2"
	requests := []RecyclingRequest{
		{ID: "pool-pending", Status: "pending"},
		{ID: "returned-to-pool", Status: "pending"},
		{ID: "cancelled-by-other", Status: "pending", CanceledHelperIDs: []string{"helper-1"}},
		{ID: "cancelled-by-current", Status: "pending", CanceledHelperIDs: []string{"helper-2"}},
		{ID: "returned-but-blocked-for-current", Status: "pending", CanceledHelperIDs: []string{"helper-2"}},
		{ID: "accepted", Status: "accepted", HelperID: helperID},
	}

	filtered := filterHelperVisiblePendingRequests(requests, helperID)
	if len(filtered) != 3 {
		t.Fatalf("len(filterHelperVisiblePendingRequests()) = %d, want 3", len(filtered))
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

func TestCompleteRequestPayloadValidation(t *testing.T) {
	t.Parallel()

	payload := CompleteRequestPayload{
		ID:              "req-101",
		ReceiptImageUrl: "https://panta.s3.amazonaws.com/receipt.jpg",
		ReceiptAmount:   55.50,
	}

	if payload.ID != "req-101" {
		t.Fatalf("unexpected id %q", payload.ID)
	}
	if payload.ReceiptAmount != 55.50 {
		t.Fatalf("unexpected receipt amount %f", payload.ReceiptAmount)
	}
}

func TestUpdateLocationPayload(t *testing.T) {
	t.Parallel()

	lat := 59.3293
	lng := 18.0686
	eta := 8
	milestone := "on_the_way"

	payload := UpdateLocationPayload{
		ID:              "req-202",
		HelperLatitude:  &lat,
		HelperLongitude: &lng,
		EtaMinutes:      &eta,
		Milestone:       milestone,
	}

	if *payload.HelperLatitude != 59.3293 || *payload.HelperLongitude != 18.0686 {
		t.Fatalf("unexpected coordinates %f, %f", *payload.HelperLatitude, *payload.HelperLongitude)
	}
	if *payload.EtaMinutes != 8 {
		t.Fatalf("unexpected eta %d", *payload.EtaMinutes)
	}
	if payload.Milestone != "on_the_way" {
		t.Fatalf("unexpected milestone %q", payload.Milestone)
	}
}

func TestCalculatePayout(t *testing.T) {
	t.Parallel()

	// 1. Standard 70/30 split
	p1 := CalculatePayout(100.0, 70.0, 0.0)
	if p1.RecyclerShare != 70.0 || p1.HelperShare != 30.0 || p1.TotalHelperEarned != 30.0 {
		t.Fatalf("unexpected standard payout: %+v", p1)
	}

	// 2. Custom 50/50 split with base reward
	p2 := CalculatePayout(80.0, 50.0, 20.0)
	if p2.RecyclerShare != 40.0 || p2.HelperShare != 40.0 || p2.TotalHelperEarned != 60.0 {
		t.Fatalf("unexpected 50/50 payout with reward: %+v", p2)
	}

	// 3. Default fallback for invalid split percentage
	p3 := CalculatePayout(50.0, 0.0, 0.0)
	if p3.SplitPercentage != 70.0 || p3.RecyclerShare != 35.0 || p3.HelperShare != 15.0 {
		t.Fatalf("unexpected default split fallback: %+v", p3)
	}

	// 4. Zero receipt amount
	p4 := CalculatePayout(0.0, 70.0, 25.0)
	if p4.RecyclerShare != 0.0 || p4.HelperShare != 0.0 || p4.TotalHelperEarned != 25.0 {
		t.Fatalf("unexpected zero receipt payout: %+v", p4)
	}
}

func TestLeaveAtDoorPayload(t *testing.T) {
	t.Parallel()

	req := RecyclingRequest{
		ID:               "req-door-1",
		Title:            "Bottles at door",
		LeaveAtDoor:      true,
		DoorInstructions: "Code 4567, 2nd floor, bag on the left",
	}

	if !req.LeaveAtDoor {
		t.Fatalf("expected LeaveAtDoor to be true")
	}
	if req.DoorInstructions != "Code 4567, 2nd floor, bag on the left" {
		t.Fatalf("unexpected DoorInstructions: %q", req.DoorInstructions)
	}

	complete := CompleteRequestPayload{
		ID:              "req-door-1",
		ReceiptAmount:   65.0,
		DropoffPhotoUrl: "https://example.com/dropoff-photo.jpg",
	}

	if complete.DropoffPhotoUrl != "https://example.com/dropoff-photo.jpg" {
		t.Fatalf("unexpected DropoffPhotoUrl: %q", complete.DropoffPhotoUrl)
	}
}

