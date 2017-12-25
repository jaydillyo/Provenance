//
//  PVTVSettingsViewController.m
//  Provenance
//
//  Created by James Addyman on 18/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVTVSettingsViewController.h"
#import "PVSettingsModel.h"
#import "PVGameLibraryViewController.h"
#import "PVGameImporter.h"
#import "PVMediaCache.h"
#import "PVConflictViewController.h"
#import "PVControllerSelectionViewController.h"
#import "Reachability.h"
#import "PVWebServer.h"

@interface PVTVSettingsViewController ()

@property (nonatomic, strong, nonnull) PVGameImporter *gameImporter;

@property (weak, nonatomic) IBOutlet UILabel *autoSaveValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *autoLoadValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *versionValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *revisionLabel;
@property (weak, nonatomic) IBOutlet UILabel *modeValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *showFPSCountValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *iCadeControllerSetting;
@property (weak, nonatomic) IBOutlet UILabel *crtFilterLabel;

@property (copy, readonly) NSString* localizedOnLabel;
@property (copy, readonly) NSString* localizedOffLabel;
@end

@implementation PVTVSettingsViewController

- (NSString *) localizedOnLabel {
    return NSLocalizedStringFromTable(@"On", @"PVTVSettingsViewController", @"On Label for Settings");
}

- (NSString *) localizedOffLabel {
    return NSLocalizedStringFromTable(@"Off", @"PVTVSettingsViewController", @"Off Label for Settings");
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _gameImporter = [[PVGameImporter alloc] initWithCompletionHandler:nil];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _gameImporter = [[PVGameImporter alloc] initWithCompletionHandler:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView setBackgroundView:nil];
    [self.tableView setBackgroundColor:[UIColor clearColor]];
}

- (void) updateLabels {
    NSString* onString = self.localizedOnLabel;
    NSString* offString = self.localizedOffLabel;
    
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];
    self.autoSaveValueLabel.text = settings.autoSave ? onString : offString;
    self.autoLoadValueLabel.text = settings.autoLoadAutoSaves ? onString : offString;
    self.showFPSCountValueLabel.text = settings.showFPSCount ? onString : offString;
    self.crtFilterLabel.text = settings.crtFilterEnabled ? onString : offString;
    
    NSString *versionText = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    versionText = [versionText stringByAppendingFormat:@" (%@)", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
    [self.versionValueLabel setText:versionText];
    
    NSString* modeString = @"RELEASE";
    
#if DEBUG
    modeString = @"DEBUG";
#endif
    
    self.modeValueLabel.text = modeString;
    
    NSString *revisionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"Revision"];
    UIColor *color = [UIColor colorWithWhite:0.0 alpha:0.1];
    
    if ([revisionString length] > 0) {
        self.revisionLabel.text = revisionString;
    } else {
        self.revisionLabel.textColor = color;
        self.revisionLabel.text = NSLocalizedStringFromTable(@"(none)", @"PVTVSettingsViewController", @"Revision label title indicating no revision found");
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.splitViewController.title = NSLocalizedStringFromTable(@"Settings", @"PVTVSettingsViewController", @"Settings View Title");
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];
    [self.iCadeControllerSetting setText:kIcadeControllerSettingToString([settings iCadeControllerSetting])];
    [self updateLabels];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PVSettingsModel *settings = [PVSettingsModel sharedInstance];
    
    switch ([indexPath section]) {
        case 0:
            // emu settings
            switch ([indexPath row]) {
                case 0:
                    // Auto save
                    settings.autoSave = !settings.autoSave;
                    break;
                case 1:
                    // auto load
                    settings.autoLoadAutoSaves = !settings.autoLoadAutoSaves;
                    break;
                case 2:
                    settings.crtFilterEnabled = !settings.crtFilterEnabled;
                    break;
                case 3:
                    settings.showFPSCount = !settings.showFPSCount;
                    break;
                default:
                    break;
            }
            [self updateLabels];
            break;
        case 1:
            // icase settings
            break;
        case 2:
            // library settings
            switch ([indexPath row]) {
                case 0: {
                    // start webserver
                    // Check to see if we are connected to WiFi. Cannot continue otherwise.
                    Reachability *reachability = [Reachability reachabilityForInternetConnection];
                    [reachability startNotifier];
                    
                    NetworkStatus status = [reachability currentReachabilityStatus];
                    
                    if (status != ReachableViaWiFi)
                    {
                        NSString *alertTitle = NSLocalizedStringFromTable(@"Unable to start web server!",
                                                                          @"PVTVSettingsViewController",
                                                                          @"Alert Title");
                        NSString *alertMessage = NSLocalizedStringFromTable(@"Your device needs to be connected to a WiFi network to continue!",
                                                                            @"PVTVSettingsViewController",
                                                                            @"Alert Message");
                        
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle: alertTitle
                                                                                       message: alertMessage
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                        
                        NSString *okButtonTitle = NSLocalizedStringFromTable(@"OK", @"PVTVSettingsViewController", @"OK button title");
                        [alert addAction:[UIAlertAction actionWithTitle:okButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        }]];
                        [self presentViewController:alert animated:YES completion:NULL];
                    } else {
                        // connected via wifi, let's continue
                        
                        // start web transfer service
                        [[PVWebServer sharedInstance] startServer];
                        
                        // get the IP address of the device
                        NSString *ipAddress = [[PVWebServer sharedInstance] getIPAddress];
                        
#if TARGET_IPHONE_SIMULATOR
                        ipAddress = [ipAddress stringByAppendingString:@":8080"];
#endif
                        NSString *alertTitle = NSLocalizedStringFromTable(@"Web server started!", @"PVTVSettingsViewController", @"Alert Title");
                        
                        NSString *alertMessageFormat = NSLocalizedStringFromTable(@"You can now upload ROMs or download saves by visiting:\nhttp://%@/\non your computer",
                                                                             @"PVTVSettingsViewController", @"Alert Message");
                        
                        NSString *alertMessage = [NSString stringWithFormat: alertMessageFormat, ipAddress];
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle: alertTitle
                                                                                       message: alertMessage
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                        
                        NSString *stopButtonTitle = NSLocalizedStringFromTable(@"Stop", @"PVTVSettingsViewController", @"Stop button title");
                        
                        [alert addAction:[UIAlertAction actionWithTitle:stopButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [[PVWebServer sharedInstance] stopServer];
                        }]];
                        [self presentViewController:alert animated:YES completion:NULL];
                    }
                }
                case 1: {
                    
                    NSString *alertTitle = NSLocalizedStringFromTable(@"Refresh Game Library?", @"PVTVSettingsViewController", @"Alert Title");
                    
                    NSString *alertMessage = NSLocalizedStringFromTable(@"Attempt to get artwork and title information for your library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork. Please be patient, as this process can take several minutes.",
                                                                         @"PVTVSettingsViewController", @"Alert Message");
                    
                    // refresh
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle
                                                                                   message:alertMessage
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    
                    NSString *yesButtonTitle = NSLocalizedStringFromTable(@"Yes", @"PVTVSettingsViewController", @"Yes button title");
                    
                    [alert addAction:[UIAlertAction actionWithTitle:yesButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshLibraryNotification
                                                                            object:nil];
                    }]];
                    
                    NSString *noButtonTitle = NSLocalizedStringFromTable(@"No", @"PVTVSettingsViewController", @"No button title");
                    
                    [alert addAction:[UIAlertAction actionWithTitle:noButtonTitle style:UIAlertActionStyleCancel handler:NULL]];
                    [self presentViewController:alert animated:YES completion:NULL];
                    break;
                }
                case 2: {
                    // empty cache
                    NSString *alertTitle = NSLocalizedStringFromTable(@"Empty Image Cache?", @"PVTVSettingsViewController", @"Alert Title");
                    
                    NSString *alertMessage = NSLocalizedStringFromTable(@"Empty the image cache to free up disk space. Images will be redownload on demand.",
                                                                         @"PVTVSettingsViewController", @"Alert Message");
                    
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle
                                                                                   message:alertMessage
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    
                    NSString *yesButtonTitle = NSLocalizedStringFromTable(@"Yes", @"PVTVSettingsViewController", @"Yes button title");
                    [alert addAction:[UIAlertAction actionWithTitle:yesButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [PVMediaCache emptyCache];
                    }]];
                    
                    
                    NSString *noButtonTitle = NSLocalizedStringFromTable(@"No", @"PVTVSettingsViewController", @"No button title");
                    [alert addAction:[UIAlertAction actionWithTitle:noButtonTitle style:UIAlertActionStyleCancel handler:NULL]];
                    [self presentViewController:alert animated:YES completion:NULL];
                    break;
                }
                case 3: {
                    PVConflictViewController *conflictViewController = [[PVConflictViewController alloc] initWithGameImporter:self.gameImporter];
                    [self.navigationController pushViewController:conflictViewController animated:YES];
                    break;
                }
                default:
                    break;
            }
            break;
        default:
            break;
    }
}

@end
