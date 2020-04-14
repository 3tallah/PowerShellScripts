[![img](https://1.bp.blogspot.com/-zcSLc5OUrhM/Xlo_SAgjzmI/AAAAAAABDbo/mghtylxbiXIm9BqXHyBHmdmV-qUdmiocwCLcBGAsYHQ/s1600/Bulk%2BPre-Register%2BMFA%2BFor%2BUsers%2BWithout%2BForcing%2BMFA.png)](https://blog.3tallah.com/2020/02/Bulk-Pre-Register-MFA-For-Users-Without-Forcing-MFA.html)

[Bulk Pre-Register MFA For Users Without Forcing MFA](https://blog.3tallah.com/2020/02/Bulk-Pre-Register-MFA-For-Users-Without-Forcing-MFA.html)



We’ve been asked many times to do a bulk pre-registration for Azure Active Directory **MFA** to provide our customers’ users more Seamless Single Sign on and smooth for MFA rolling out.

This script helping you to:

1. Configure **MFA** Strong Authentication Methods
2. Set a default **MFA** authentication method for all users or number of users.
3. Update Mobile Number for a List of users.
4. Update Strong Authentication Methods for List of users
5. Get **MFA** Strong Authentication Details for all users.
6. Get **MFA** Authentication contact info where the phone number is Null
7. Update Mobile Number Only If user Mobile is not exist

*NOTE : Before we proceed with MFA and SSPR Enablement and configuration,* *Users will be able to change their Authentication mobile phone number whenever they need to, Admins won’t have a control on Authentication mobile phone number however they can pre-define them but still users will be able to change it.*

*
*

**Keep in mind:**

- If you have provided a value for **Mobile phone** or **Alternate email**, users can immediately use those values to reset their passwords, even if they haven't registered for the service. In addition, users see those values when they register for the first time, and they can modify them if they want to. After they register successfully, these values are persisted in the **Authentication Phone** and **Authentication Email** fields, respectively.
- If the **Phone**field is populated and **Mobile phone** is enabled in the SSPR policy, the user sees that number on the password reset registration page and during the password reset workflow.
- The **Alternate phone**field isn't used for password reset.
- If the **Email**field is populated and **Email** is enabled in the SSPR policy, the user sees that email on the password reset registration page and during the password reset workflow.
- If the **Alternate email**field is populated and **Email** is enabled in the SSPR policy, the user **won't** see that email on the password reset registration page, but they see it during the password reset workflow.

 

For more information on the script, please check my Post; [here](https://blog.3tallah.com/2020/02/Bulk-Pre-Register-MFA-For-Users-Without-Forcing-MFA.html).

Tags
Microsoft Azure, Powershell, Powershell Script, O365, Microsoft Azure active directory, Azure AD, MFA, Enable MFA, Azure AD Powershell
