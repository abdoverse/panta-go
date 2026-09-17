package main

import (
	"testing"
)

func TestClaimsIsParticipant(t *testing.T) {
	t.Parallel()

	erikEmailUUID := userUUID("erik.helper@example.com")
	erikNameUUID := userUUID("Erik Helper")
	annaEmailUUID := userUUID("anna.recycler@example.com")
	annaNameUUID := userUUID("Anna Recycler")
	unrelatedUUID := userUUID("random.user@example.com")

	helperClaims := &Claims{
		Role:            "helper",
		DisplayName:     "Erik Helper",
		Email:           "erik.helper@example.com",
		CognitoUsername: "Erik Helper",
		UserID:          erikEmailUUID,
	}

	recyclerClaims := &Claims{
		Role:            "user",
		DisplayName:     "Anna Recycler",
		Email:           "anna.recycler@example.com",
		CognitoUsername: "Anna Recycler",
		UserID:          annaEmailUUID,
	}

	adminClaims := &Claims{
		Role:        "admin",
		DisplayName: "Admin Operator",
		Email:       "admin.operator@example.com",
		UserID:      userUUID("admin.operator@example.com"),
	}

	unrelatedClaims := &Claims{
		Role:        "user",
		DisplayName: "Sara Other",
		Email:       "sara.other@example.com",
		UserID:      unrelatedUUID,
	}

	// 1. Helper matches request with erikEmailUUID
	if !helperClaims.isParticipant(annaEmailUUID, erikEmailUUID) {
		t.Errorf("expected helper to be participant with erikEmailUUID")
	}

	// 2. Helper matches request with erikNameUUID (persona alias)
	if !helperClaims.isParticipant(annaEmailUUID, erikNameUUID) {
		t.Errorf("expected helper to be participant with erikNameUUID")
	}

	// 3. Helper matches request with literal name
	if !helperClaims.isParticipant(annaEmailUUID, "Erik Helper") {
		t.Errorf("expected helper to be participant with literal name")
	}

	// 4. Recycler matches request with annaEmailUUID
	if !recyclerClaims.isParticipant(annaEmailUUID, erikEmailUUID) {
		t.Errorf("expected recycler to be participant with annaEmailUUID")
	}

	// 5. Recycler matches request with annaNameUUID (persona alias)
	if !recyclerClaims.isParticipant(annaNameUUID, erikEmailUUID) {
		t.Errorf("expected recycler to be participant with annaNameUUID")
	}

	// 6. Recycler matches request with literal name
	if !recyclerClaims.isParticipant("Anna Recycler", erikEmailUUID) {
		t.Errorf("expected recycler to be participant with literal name")
	}

	// 7. Admin is always participant
	if !adminClaims.isParticipant(annaEmailUUID, erikEmailUUID) {
		t.Errorf("expected admin to be participant")
	}

	// 8. Unrelated user is NOT a participant
	if unrelatedClaims.isParticipant(annaEmailUUID, erikEmailUUID) {
		t.Errorf("expected unrelated user to NOT be participant")
	}

	// 9. Nil claims or empty targets
	var nilClaims *Claims
	if nilClaims.isParticipant(annaEmailUUID, erikEmailUUID) {
		t.Errorf("nil claims should not be participant")
	}
	if helperClaims.isParticipant("", "") {
		t.Errorf("empty targets should not be participant")
	}
}

func TestHelperIDsMatch(t *testing.T) {
	t.Parallel()

	erikEmailUUID := userUUID("erik.helper@example.com")
	erikNameUUID := userUUID("Erik Helper")
	annaEmailUUID := userUUID("anna.recycler@example.com")
	annaNameUUID := userUUID("Anna Recycler")

	// Exact match
	if !helperIDsMatch("helper-123", "helper-123") {
		t.Errorf("expected exact match to succeed")
	}

	// Case-insensitive match
	if !helperIDsMatch("HELPER-ABC", "helper-abc") {
		t.Errorf("expected case-insensitive match to succeed")
	}

	// Erik aliases match
	if !helperIDsMatch(erikEmailUUID, erikNameUUID) {
		t.Errorf("expected Erik email UUID and name UUID to match as aliases")
	}
	if !helperIDsMatch(erikNameUUID, erikEmailUUID) {
		t.Errorf("expected Erik name UUID and email UUID to match symmetrically")
	}

	// Anna aliases match
	if !helperIDsMatch(annaEmailUUID, annaNameUUID) {
		t.Errorf("expected Anna email UUID and name UUID to match as aliases")
	}

	// Different users do not match
	if helperIDsMatch(erikEmailUUID, annaEmailUUID) {
		t.Errorf("expected Erik and Anna UUIDs to NOT match")
	}
	if helperIDsMatch("helper-1", "helper-2") {
		t.Errorf("expected distinct helper IDs to NOT match")
	}
	if helperIDsMatch("", "helper-1") || helperIDsMatch("helper-1", "") {
		t.Errorf("expected empty helper IDs to NOT match")
	}
}
