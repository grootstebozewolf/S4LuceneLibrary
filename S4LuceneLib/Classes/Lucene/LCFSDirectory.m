#include "LCFSDirectory.h"
#include "LCFSIndexInput.h"
#include "LCFSIndexOutput.h"
#include "GNUstep.h"

#import "S4FileUtilities.h"




/**
* Straightforward implementation of {@link Directory} as a directory of files.
 * <p>If the system property 'disableLuceneLocks' has the String value of
 * "true", lock creation will be disabled.
 *
 * @see Directory
 * @author Doug Cutting
 */
@implementation LCFSDirectory

+ (LCFSDirectory *) directoryAtPath: (NSString *) absolutePath
						  create: (BOOL) create
{
	LCFSDirectory *dir = [[LCFSDirectory alloc] initWithPath: absolutePath
													  create: create];
	return AUTORELEASE(dir);
}


- (BOOL)create // Create new directory, remove existed
{
	[S4FileUtilities deleteDiskItemAtPath: path];
	return ([S4FileUtilities createDirectory: path]);
}

			 
- (id)initWithPath: (NSString *)p create: (BOOL)b
{
	self = [self init];
	if (nil != self)
	{
		manager = [[NSFileManager alloc] init];
		path = [p copy];
		if (b) 
		{
			if ([self create] == NO)
			{	
				NSLog(@"Unable to create directory");
				DESTROY(manager);
				DESTROY(path);
				[self release];
				return nil;
			}
		}

		if ([S4FileUtilities isDirectoryAtPath: path] == NO)
		{
			NSLog(@"Not a directory");
			DESTROY(manager);
			DESTROY(path);
			[self release];
			return nil;
		}
	}
	return self;
}

- (void) dealloc
{
	DESTROY(manager);
	DESTROY(path);
	[super dealloc];
}

/** Returns an array of strings, one for each file in the directory. */
- (NSArray *)fileList
{
	return [S4FileUtilities directoryContentsNames: path];
}



/** Returns true iff a file with the given name exists. */
- (BOOL)fileExists: (NSString *)name
{
	NSString *p = [path stringByAppendingPathComponent: name];
	return [manager fileExistsAtPath: p];
}

/** Returns the time the named file was last modified. */
- (NSTimeInterval)fileModified: (NSString *) name
{
	NSString *p = [path stringByAppendingPathComponent: name];
	NSDictionary *d = [S4FileUtilities attributesOfItemAtPath: p];
	return [[d objectForKey: NSFileModificationDate] timeIntervalSince1970];
}

/** Set the modified time of an existing file to now. */
- (void) touchFile: (NSString *) name
{
	NSString *p = [path stringByAppendingPathComponent: name];
	NSDictionary *d = [S4FileUtilities attributesOfItemAtPath: p];
	NSMutableDictionary *n = [NSMutableDictionary dictionaryWithDictionary: d];
	[n setObject: [NSDate date] forKey: NSFileModificationDate];
	[manager setAttributes: n ofItemAtPath: p error: NULL];
}

/** Returns the length in bytes of a file in the directory. */
- (unsigned long long) fileLength: (NSString *) name
{
	NSString *p = [path stringByAppendingPathComponent: name];
	NSDictionary *d = [S4FileUtilities attributesOfItemAtPath: p];
	return [[d objectForKey: NSFileSize] unsignedLongLongValue];
}

/** Removes an existing file in the directory. */
- (BOOL)deleteFile: (NSString *)name
{
	NSString *p = [path stringByAppendingPathComponent: name];
    if ([manager fileExistsAtPath: p] == YES)
    {
		if ([manager removeItemAtPath: p error: NULL] == NO)
    	{
			NSLog(@"Cannot remove file %@", p);
			return NO;
		}
    }
	return YES;
}

/** Renames an existing file in the directory. */
- (void)renameFile: (NSString *)from to: (NSString *)to
{
	NSString *old, *nu;
	old = [path stringByAppendingPathComponent: from];
	nu = [path stringByAppendingPathComponent: to];
	
	if ([manager fileExistsAtPath: old] == NO)
    {
		return;
    }

	if ([manager fileExistsAtPath: nu] == YES)
    {
		if ([manager removeItemAtPath: nu error: NULL] == NO)
        {
			NSLog(@"Cannot remove %@", nu);
			return;
		}
    }
	[manager moveItemAtPath: old toPath: nu error: NULL];
}


/** Creates a new, empty file in the directory with the given name.
Returns a stream writing this file. */
- (LCIndexOutput *) createOutput: (NSString *) name
{
//FIXME: should delete old file and create new one.
/*  File file = new File(directory, name);
 	     if (file.exists() && !file.delete())          // delete existing, if any
	      	       throw new IOException("Cannot overwrite: " + file);
		       */
	NSString *p = [path stringByAppendingPathComponent: name];
	LCFSIndexOutput *output = [[LCFSIndexOutput alloc] initWithFile: p];
	return AUTORELEASE(output);
}

/** Returns a stream reading an existing file. */
- (LCIndexInput *) openInput: (NSString *) name
{
	NSString *p = [path stringByAppendingPathComponent: name];
       if ([manager fileExistsAtPath: p] == YES)
       {
	  LCFSIndexInput *input = [[LCFSIndexInput alloc] initWithFile: p];
	  return AUTORELEASE(input);
       }
       else
       {
          NSLog(@"File %@ does not exist", p);
	  return nil;
       }
}

/**
* So we can do some byte-to-hexchar conversion below
 */
#if 0
private static final char[] HEX_DIGITS =
{'0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'};
#endif

/** Constructs a {@link Lock} with the specified name.  Locks are implemented
* with {@link File#createNewFile() }.
*
* <p>In JDK 1.1 or if system property <I>disableLuceneLocks</I> is the
* string "true", locks are disabled.  Assigning this property any other
* string will <B>not</B> prevent creation of lock files.  This is useful for
* using Lucene on read-only medium, such as CD-ROM.
*
* @param name the name of the lock file
* @return an instance of <code>Lock</code> holding the lock
*/
#if 0
public Lock makeLock(String name) {
    StringBuffer buf = getLockPrefix();
    buf.append("-");
    buf.append(name);
	
    // create a lock file
    final File lockFile = new File(lockDir, buf.toString());
	
    return new Lock() {
		public boolean obtain() throws IOException {
			if (DISABLE_LOCKS)
				return true;
			
			if (!lockDir.exists()) {
				if (!lockDir.mkdirs()) {
					throw new IOException("Cannot create lock directory: " + lockDir);
				}
			}
			
			return lockFile.createNewFile();
		}
		public void release() {
			if (DISABLE_LOCKS)
				return;
			lockFile.delete();
		}
		public boolean isLocked() {
			if (DISABLE_LOCKS)
				return false;
			return lockFile.exists();
		}
		
		public String toString() {
			return "Lock@" + lockFile;
		}
    };
}
#endif

#if 0
private StringBuffer getLockPrefix() {
    String dirName;                               // name to be hashed
    try {
		dirName = directory.getCanonicalPath();
    } catch (IOException e) {
		throw new RuntimeException(e.toString());
    }
	
    byte digest[];
    synchronized (DIGESTER) {
		digest = DIGESTER.digest(dirName.getBytes());
    }
    StringBuffer buf = new StringBuffer();
    buf.append("lucene-");
    for (int i = 0; i < digest.length; i++) {
		int b = digest[i];
		buf.append(HEX_DIGITS[(b >> 4) & 0xf]);
		buf.append(HEX_DIGITS[b & 0xf]);
    }
	
    return buf;
}
#endif

/** Closes the store to future operations. */
- (void) close
{
}

/** For debug output. */
- (NSString *) description
{
	return [NSString stringWithFormat: @"%@@%@", NSStringFromClass([self class]), path];
}

@end
