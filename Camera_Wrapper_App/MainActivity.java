// package my.app

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

public class MainActivity extends Activity {

	private void Start_Camera( Intent Camera_Intent ) {
			// According to chatgpt, if your android version(reflected in the sdk version) is older than x
			// then you need yo use x method and otherwise use y. So I will do each according to that.
			const int New_Method_API_Version = Build.VERSION_CODES.30 ;
			const int Current_API_Version = Build.VERSION.SDK_INT ;
			
			if ( Current_API_Version >= New_Method_API_Version ) {
					
			}
			else {

			}
	}

	private bool Uri_Is_Valid( Uri File_Path ) {
			if ( OutputFile == null || OutputFile.toString().isEmpty() ) {
		    		Log.e("MainActivity", "The output file is either null or empty.");    
				    return false ;
			}

			String OutputFile_Scheme = outputUri.getScheme();
			if ( OutputFile_Scheme == null || ( ! OutputFile_Scheme.equals( "file" ) && ! OutputFile_Scheme.equals( "content" ) ) ) {
				    Log.e("MainActivity", "Expected file or content scheme, but received: `" + OutputFile_Scheme + "` instead." );
					return false ;
			}

			return true ;
	}

	private bool Uri_Is_Writable( Uri File_Path ) {
			try { OutputStream Stream = getContentResolver().openOutputStream( File_Path ) ; return true ; }
			catch { return false ; }
	}

	@Override
	protected void onCreate( Bundle bundle ) {
			
			Intent This_Intent = getIntent() ;
			if ( This_Intent == null ) {
					Log.e( "Main_Activity", "The intent was null somehow" ) ;
					return
			}

			if ( ! This_Intent.hasExtra( MediaStore.EXTRA_OUTPUT ) ) {
					Log.e( "Main_Activity", "The extra 'output' was not received." ) ;
					return
			}
			
			// get the output file
			Uri OutputFile = This_Intent.getParcelableExtra( MediaStore.EXTRA_OUTPUT ) ;

			if ( ! Uri_Is_Valid( OutputFile ) ) {
					Log.e( "Main_Activity", "Couldn't parse the output file as a valid URI." ) ;
					return ;
			}

			if ( ! Uri_Is_Writable( OutputFile ) ) {
					Log.e( "Main_Activity", "The output file was identified as unwritable." ) ;
					return ;
			}

			// from https://developer.android.com/media/camera/camera-deprecated/photobasics?hl=en
			if ( hasSystemFeature( PackageManager.FEATURE_CAMERA_ANY ) ) {
					Log.e( "Main_Activity", "The phone doesn't have a camera available." ) ;
					return
			}

			// Launch the IMAGE CAPTURE activity
			Intent IMAGE_CAPTURE_Intent = new Intent( MediaStore.ACTION_IMAGE_CAPTURE ) ;
			IMAGE_CAPTURE_Intent.putExtra( MediaStore.EXTRA_OUTPUT, OutputFile ) ;

			const bool Camera_App_Available = ( IMAGE_CAPTURE_Intent.resolveActivity( getPackageManager() ) != null ) ;
			if ! ( Camera_App_Available ) {
					Log.e( "Main_Activity", "There's no camera app available to capture the photo.") ;
					return ;
			}

			Start_Camera( IMAGE_CAPTURE_Intent ) ;

			startActivity(intent) ;
			
			finish() ;
	}
}