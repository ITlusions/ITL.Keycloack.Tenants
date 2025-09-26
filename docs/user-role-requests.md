# Keycloak User Role Request Configuration

This guide explains how to configure Keycloak to allow users to request certain roles through fine-grained authorization and self-service features.

## 🎯 **Overview**

With fine-grained authorization enabled, Keycloak supports several ways for users to request roles:

1. **Direct Role Requests** - Users request specific roles
2. **Group Membership Requests** - Users request to join groups (which have roles)
3. **Application-Specific Role Requests** - Request roles for specific applications
4. **Workflow-Based Approvals** - Admin approval workflows for role assignments

## 🔧 **Configuration**

### **1. Required Features**

The following features are enabled in your Helm configuration:

```yaml
features:
  - admin-fine-grained-authz-v2    # Fine-grained admin permissions
  - account3                       # Enhanced Account Console
  - authorization                  # Authorization Services
  - dynamic-scopes                 # Dynamic OAuth scopes
```

### **2. Realm Configuration**

After deployment, configure your realm through the Admin Console:

#### **Enable Fine-Grained Permissions**

1. **Admin Console** → **Realm Settings** → **General**
2. **Enable** → **User Registration** (if needed)
3. **Enable** → **Edit Username** (if needed)
4. **Enable** → **User Profile Enabled**

#### **Configure User Profile**

1. **Admin Console** → **Realm Settings** → **User Profile**
2. **Add Attributes** for role request metadata:
   - `requested_roles` (optional, array)
   - `role_request_reason` (optional, text)
   - `department` (for automatic role assignment)

### **3. Role Request Methods**

#### **Method 1: Direct Role Requests via Account Console**

**Setup:**
1. **Admin Console** → **Realm Settings** → **Login**
2. **Enable** → **User Registration**
3. **Roles** → **Default Roles** → Configure requestable roles

**User Experience:**
```
Account Console → Personal Info → Request Role
User selects: "Developer", "QA Tester", "Project Manager"
Admin receives notification for approval
```

#### **Method 2: Group-Based Role Requests**

**Setup Groups with Roles:**
```bash
# Example groups with associated roles
Groups:
  - developers (roles: developer, code-reviewer)
  - qa-team (roles: qa-tester, bug-reporter)
  - project-managers (roles: pm, resource-manager)
```

**Configuration:**
1. **Admin Console** → **Groups**
2. **Create Groups** → Assign roles to groups
3. **Group Settings** → **Enable** → **User can request membership**

#### **Method 3: Application-Specific Requests**

**For GitLab Integration:**
```yaml
# GitLab Client Scopes
gitlab_roles:
  - gitlab:developer
  - gitlab:maintainer
  - gitlab:owner

# Users can request these through OAuth flow
```

## 🛠️ **Implementation Steps**

### **Step 1: Deploy with Fine-Grained Features**

Your Helm chart now includes the necessary features. Deploy it:

```bash
helm upgrade --install keycloak-tenant ./charts/keycloak-tenants \
  -f tenants/itlkc01.yaml \
  --namespace keycloak
```

### **Step 2: Configure Realm Permissions**

**Enable User Self-Service:**

1. **Admin Console** → **Users** → **Permissions**
2. **Enable** → **Permissions Enabled**
3. **Policies** → **Create User Policy**:
   ```json
   {
     "name": "Self-Service Policy",
     "description": "Allow users to request roles",
     "logic": "POSITIVE",
     "users": ["authenticated-users"]
   }
   ```

### **Step 3: Create Role Request Workflow**

**Custom Authentication Flow:**

1. **Admin Console** → **Authentication** → **Flows**
2. **Create Flow** → "Role Request Flow"
3. **Add Execution** → "Role Request Review"

**Approval Process:**
```javascript
// Custom JavaScript for role approval
function approveRoleRequest(user, requestedRole, reason) {
  // Send notification to admin
  sendAdminNotification({
    user: user.username,
    role: requestedRole,
    reason: reason,
    timestamp: new Date()
  });
  
  // Create approval task
  createApprovalTask({
    type: 'ROLE_REQUEST',
    user: user.id,
    role: requestedRole,
    status: 'PENDING'
  });
}
```

### **Step 4: Configure Account Console**

**Enhanced Account Console (Account 3.0):**

1. **Account Console URL**: `https://sts.itlusions.com/realms/master/account/`
2. **Enable Features**:
   - Personal Info editing
   - Role request interface
   - Group membership requests
   - Application access requests

### **Step 5: Set Up Notifications**

**Email Notifications for Admins:**

1. **Admin Console** → **Realm Settings** → **Email**
2. **Configure SMTP** settings
3. **Events** → **Enable** → "ROLE_REQUEST_CREATED"

**Webhook Notifications:**
```yaml
# In your values.yaml
keycloak:
  additionalOptions:
    - name: spi-events-listener-webhook-url
      value: "https://your-webhook.itlusions.com/keycloak-events"
```

## 🔐 **Security Considerations**

### **Role Request Policies**

**Limit Requestable Roles:**
```json
{
  "requestable_roles": [
    "developer",
    "qa-tester",
    "content-editor"
  ],
  "restricted_roles": [
    "admin",
    "system-administrator",
    "billing-admin"
  ]
}
```

**Approval Requirements:**
```yaml
role_approval_rules:
  developer:
    approvers: ["team-lead", "tech-manager"]
    auto_approve: false
  qa-tester:
    approvers: ["qa-manager"]
    auto_approve: true  # for verified team members
  admin:
    approvers: ["system-admin", "security-team"]
    auto_approve: false
    requires_justification: true
```

### **Audit Trail**

**Track Role Requests:**
```sql
-- Example audit queries
SELECT 
  user_id,
  requested_role,
  request_timestamp,
  approved_by,
  approval_timestamp,
  status
FROM role_requests 
WHERE status = 'APPROVED'
ORDER BY request_timestamp DESC;
```

## 🎭 **User Experience Examples**

### **Scenario 1: Developer Requesting QA Access**

1. **User** → Account Console → "Request Role"
2. **Select Role** → "QA Tester"
3. **Provide Reason** → "Need to test my own features"
4. **Submit Request**
5. **QA Manager** receives email notification
6. **Approval** → Role automatically assigned

### **Scenario 2: Contractor Requesting Project Access**

1. **User** → Account Console → "Request Group Membership"
2. **Select Group** → "Project-Alpha-Team"
3. **Provide Details** → "Contractor working on Alpha project"
4. **Project Manager** reviews and approves
5. **Automatic Role Assignment** → Gets all project-related roles

### **Scenario 3: Temporary Elevated Access**

1. **User** → Account Console → "Request Temporary Role"
2. **Select Role** → "Production-Debugger"
3. **Duration** → "2 hours"
4. **Justification** → "Critical production issue #12345"
5. **Immediate Approval** → For emergency situations
6. **Automatic Revocation** → After specified time

## 📊 **Monitoring & Analytics**

### **Role Request Metrics**

```yaml
# Grafana Dashboard Queries
role_requests_total: sum(rate(keycloak_role_requests_total[5m]))
approval_time_avg: avg(keycloak_role_approval_duration_seconds)
rejection_rate: rate(keycloak_role_requests_rejected_total[5m])
```

### **Common Request Patterns**

- **Most Requested Roles**: developer, qa-tester, content-editor
- **Peak Request Times**: Monday mornings, after new project starts
- **Average Approval Time**: 2-4 hours for standard roles
- **Rejection Reasons**: Insufficient justification, policy violations

## 🚀 **Advanced Features**

### **Dynamic Role Assignment**

```javascript
// Auto-assign roles based on user attributes
function autoAssignRoles(user) {
  if (user.department === 'Engineering') {
    assignRole(user, 'developer');
  }
  if (user.team && user.team.includes('qa')) {
    assignRole(user, 'qa-tester');
  }
}
```

### **Integration with External Systems**

```yaml
# LDAP Group Sync
ldap_group_mapping:
  "CN=Developers,OU=Teams,DC=itlusions,DC=com": "developer"
  "CN=QA Team,OU=Teams,DC=itlusions,DC=com": "qa-tester"

# GitHub Team Sync
github_team_mapping:
  "itlusions/developers": "developer"
  "itlusions/qa-team": "qa-tester"
```

---

This configuration enables comprehensive user role request capabilities while maintaining security and auditability! 🎉