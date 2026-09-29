@SAP-001 @smoke @sap @auth
Feature: SAP user session
  As an authorized SAP user
  I want to open and close a controlled session
  So that business tests do not share authentication state

  Scenario: Log in and log out of SAP
    Given the SAP test environment is available
    And valid credentials are provided by the configured key vault
    When the user logs in
    Then the SAP home screen should be displayed
    When the user logs out
    Then the SAP login screen should be displayed
