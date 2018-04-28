1. Notes: robot client install python and PIL tool
client only install python-2.7.12.msi, Otherwise PIL (PIL-1.1.7.win32-py2.7.exe) tool installation failed

2. auto_scard directory deployed in the client side of the robot test environment.

3. scard_auto.conf smart card is automatically logged in the automated test configuration file.
	[setting]
	user_name: username, not used yet
	app_name: linuxVDA group name
	VDA_name: Log in to the remote client name of the open LinuxVDA
	ddc_url: URL of the DDC
	PIN_passwd: valid password for smart card
	Incorrect_passwd: Invalid password for smart card

	[cood]
	citrix_receiver_desktops_x: Smart card Login DDC URL After successful Desktop column X coordinate value
	citrix_receiver_desktops_y:

	vda_pin_center_x: The X coordinate value of the center position of the PIN code input box that is displayed when the LinuxVDA remote client is successfully opened
	vda_pin_center_y:

	vda_pin_passwd_x: The password field of the PIN code input box pops up when the LinuxVDA remote client is successfully opened. X coordinate value
	vda_pin_passwd_y:

	vda_pin_ok_button_x: 'OK' button of the PIN code input box pop up when the LinuxVDA remote client is successfully opened. X coordinate value
	vda_pin_ok_button_y:


	[times]
	proc_wait_time: 30
	opt_wait_time: 5

	[default]
	work_path: X coordinate of the center position of the PIN code input box that is displayed when the LinuxVDA remote client is successfully opened
	ps_logfile: logs \ ps.log
	py_logfile: logs \ py.log

4. mouse.exe 
  Run the mouse.exe program can get the coordinates of the window and control buttons.
IE is recommended to set as the default maximum.

5. Internet Explorer Setting
  Set the URL of the DDC as a trusted site on Internet Explorer and set the security level to low

6. certificate install in robot client
Need to install root root certificate and ddc certificate on robot client

7. Test Incorrect PIN passward The test case should be noted.
This test-case can not be tested three times in succession otherwise the card will lock.
Once the lock needs to be re-registered to generate a certificate.

8. After the environment is installed and set up, enter the URL by manually opening IE and using smart card to log in successfully before performing automated tests.
The purpose is to manually use the smart card login can detect the environment to build is correct.

9. 