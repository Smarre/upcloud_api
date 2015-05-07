Feature: everyone must not be able to modify everyone’s servers, so there is
password protection to prevent unauthorized parties to take over your VPS

    @invalid_account
    Scenario: you have shiny new VPS where you need to log in
        When you try to log in to VPS with user "nyawr" and password "nyuwr"
        Then login should succeed