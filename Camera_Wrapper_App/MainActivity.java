// package my.app

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

public class MainActivity extends Activity {

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

			// from https://developer.android.com/media/camera/camera-deprecated/photobasics?hl=en
			if ( hasSystemFeature( PackageManager.FEATURE_CAMERA_ANY ) ) {
					Log.e( "Main_Activity", "The phone doesn't have a camera available." ) ;
					return
			}

			// get the output file
			Uri OutputFile = This_Intent.getParcelableExtra( MediaStore.EXTRA_OUTPUT ) ;
			
			// Launch the IMAGE CAPTURE activity
			Intent IMAGE_CAPTURE_Intent = new Intent( MediaStore.ACTION_IMAGE_CAPTURE ) ;
			startActivity(intent) ;

			finish() ;
	}
}