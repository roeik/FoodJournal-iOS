//
//  FJWordPressComAccountDetailViewController.m
//  Food Journal
//
//  Created by Alexsander Akers on 2/2/13.
//  Copyright (c) 2013 Pandamonia LLC. All rights reserved.
//

#import "FJWordPressAPIClient.h"
#import "FJWordPressComAccountDetailViewController.h"
#import "WordPressAccount.h"

static NSString *const FJCloseAddAccountSegueIdentifier = @"CloseAddAccount";

@interface FJWordPressComAccountDetailViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *usernameTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) UITextField *currentTextField;

@end

@implementation FJWordPressComAccountDetailViewController

#pragma mark - Actions

- (IBAction)next:(id)sender
{
	[self.currentTextField resignFirstResponder];
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@.wordpress.com/", self.usernameTextField.text]];
	NSString *username = self.usernameTextField.text;
	NSString *password = self.passwordTextField.text;
	[WordPressAccount validateAndCreateAccountWithURL:url username:username password:password completion:^(WordPressAccount *account) {
		if (account)
			[self performSegueWithIdentifier:FJCloseAddAccountSegueIdentifier sender:self];
	}];
}
- (IBAction)save:(id)sender
{
	[self.currentTextField resignFirstResponder];
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@.wordpress.com/", self.usernameTextField.text]];
	NSString *username = self.usernameTextField.text;
	NSString *password = self.passwordTextField.text;
	if ([password isEqualToString:[@"" stringByPaddingToLength:10 withString:@"\0" startingAtIndex:0]])
		password = self.wordPressAccount.password;

	DZProgressController *progressController = [[DZProgressController alloc] init];
	progressController.label.font = [UIFont boldSystemFontOfSize: [UIFont labelFontSize]];
	progressController.label.text = NSLocalizedStringWithDefaultValue(@"Signing in...", nil, [NSBundle mainBundle], @"Signing in…", nil);
	[progressController show];

	[WordPressAccount validateAccountWithURL:url username:username password:password success:^(BOOL valid) {
		if (valid)
		{
			[progressController performChanges:^{
				progressController.customView = DZProgressControllerSuccessView;
				progressController.label.text = NSLocalizedString(@"Success!", nil);
			}];
			[progressController performSelector:@selector(hide) withObject:nil afterDelay:1.0];
			
			self.wordPressAccount.url = [url absoluteString];
			self.wordPressAccount.username = username;
			self.wordPressAccount.password = password;
			
			double delayInSeconds = 2.0;
			dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
			dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
				[self.navigationController popViewControllerAnimated:YES];
			});

		}
		else
		{
			[progressController performChanges:^{
				progressController.customView = DZProgressControllerErrorView;
				progressController.label.text = NSLocalizedString(@"Invalid username and/or password.", nil);
			}];
			[progressController performSelector:@selector(hide) withObject:nil afterDelay:3.0];
		}
	} failure:^(NSError *error) {
		[progressController performChanges:^{
			progressController.customView = DZProgressControllerErrorView;
			progressController.label.text = error.localizedDescription;
		}];
		[progressController performSelector:@selector(hide) withObject:nil afterDelay:3.0];
	}];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1 + !!(self.wordPressAccount && !self.wordPressAccount.hasTokenValue);
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (self.wordPressAccount.hasTokenValue)
		return [super tableView:tableView numberOfRowsInSection:1];
	else
		return [super tableView:tableView numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (self.wordPressAccount.hasTokenValue)
		return [super tableView:tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:1]];
	else
		return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == !self.wordPressAccount.hasTokenValue)
	{
		UIActionSheet *actionSheet = [UIActionSheet actionSheetWithTitle:nil];
		[actionSheet setDestructiveButtonWithTitle:NSLocalizedString(@"Delete", nil) handler:^{
			[self.wordPressAccount delete];
			[self.wordPressAccount.managedObjectContext save];
			[self.navigationController popViewControllerAnimated:YES];
		}];
		[actionSheet setCancelButtonWithTitle:NSLocalizedString(@"Cancel", nil) handler:^{
			[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
		}];
		[actionSheet showFromToolbar:self.navigationController.toolbar];
		return;
	}
	
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	UITextField *textField = [cell.contentView.subviews match:^BOOL(id obj) {
		return [obj isKindOfClass:[UITextField class]];
	}];
	[textField becomeFirstResponder];
}

#pragma mark - Text Field Delegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	self.navigationItem.rightBarButtonItem.enabled = !!(self.usernameTextField.text.length > 0 && self.passwordTextField.text.length > 0);
	return YES;
}
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
	self.currentTextField = textField;
	return YES;
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	self.currentTextField = nil;
	
	if ([textField isEqual:self.usernameTextField])
	{
		[self.passwordTextField becomeFirstResponder];
	}
	else if ([textField isEqual:self.passwordTextField])
	{
		[self.usernameTextField becomeFirstResponder];
	}
	
	self.navigationItem.rightBarButtonItem.enabled = !!(self.usernameTextField.text.length > 0 && self.passwordTextField.text.length > 0);
	
	return YES;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if (self.wordPressAccount)
	{
		self.title = self.wordPressAccount.title;
		
		if (self.wordPressAccount.hasTokenValue)
		{
			self.navigationItem.rightBarButtonItem = nil;
		}
		else
		{
			self.passwordTextField.text = [@"" stringByPaddingToLength:10 withString:@"\0" startingAtIndex:0];
			self.usernameTextField.text = self.wordPressAccount.username;
			
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save:)];
		}
	}
}

@end
